// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

import "./IERC20.sol";
import "./IsOHM.sol";
import "./IwsOHM.sol";
import "./IgOHM.sol";
import "./ITreasury.sol";
import "./IStaking.sol";
import "./IOwnable.sol";
import "./IUniswapV2Router.sol";
import "./IStakingV1.sol";
import "./ITreasuryV1.sol";

import "./OlympusAccessControlled.sol";

import "./SafeMath.sol";
import "./SafeERC20.sol";

contract ExodusTokenMigrator is ExodusAccessControlled {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IgEXO;
    using SafeERC20 for IsEXO;
    using SafeERC20 for IwsEXO;

    /* ========== MIGRATION ========== */

    event TimelockStarted(uint256 block, uint256 end);
    event Migrated(address staking, address treasury);
    event Funded(uint256 amount);
    event Defunded(uint256 amount);

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable oldEXO;
    IsEXO public immutable oldsEXO;
    IwsEXO public immutable oldwsEXO;
    ITreasuryV1 public immutable oldTreasury;
    IStakingV1 public immutable oldStaking;

    IUniswapV2Router public immutable sushiRouter;
    IUniswapV2Router public immutable uniRouter;

    IgEXO public gEXO;
    ITreasury public newTreasury;
    IStaking public newStaking;
    IERC20 public newEXO;

    bool public exoMigrated;
    bool public shutdown;

    uint256 public immutable timelockLength;
    uint256 public timelockEnd;

    uint256 public oldSupply;

    constructor(
        address _oldEXO,
        address _oldsEXO,
        address _oldTreasury,
        address _oldStaking,
        address _oldwsEXO,
        address _sushi,
        address _uni,
        uint256 _timelock,
        address _authority
    ) ExodusAccessControlled(IExodusAuthority(_authority)) {
        require(_oldEXO != address(0), "Zero address: EXO");
        oldEXO = IERC20(_oldEXO);
        require(_oldsEXO != address(0), "Zero address: sEXO");
        oldsEXO = IsEXO(_oldsEXO);
        require(_oldTreasury != address(0), "Zero address: Treasury");
        oldTreasury = ITreasuryV1(_oldTreasury);
        require(_oldStaking != address(0), "Zero address: Staking");
        oldStaking = IStakingV1(_oldStaking);
        require(_oldwsEXO != address(0), "Zero address: wsEXO");
        oldwsEXO = IwsEXO(_oldwsEXO);
        require(_sushi != address(0), "Zero address: Sushi");
        sushiRouter = IUniswapV2Router(_sushi);
        require(_uni != address(0), "Zero address: Uni");
        uniRouter = IUniswapV2Router(_uni); 
        timelockLength = _timelock;
    }

    /* ========== MIGRATION ========== */

    enum TYPE {
        UNSTAKED,
        STAKED,
        WRAPPED
    }

    // migrate OHMv1, sOHMv1, or wsOHM for OHMv2, sOHMv2, or gOHM
    function migrate(
        uint256 _amount,
        TYPE _from,
        TYPE _to
    ) external {
        require(!shutdown, "Shut down");

        uint256 wAmount = oldwsEXO.sOHMTowOHM(_amount);

        if (_from == TYPE.UNSTAKED) {
            require(exoMigrated, "Only staked until migration");
            oldEXO.safeTransferFrom(msg.sender, address(this), _amount);
        } else if (_from == TYPE.STAKED) {
            oldsEXO.safeTransferFrom(msg.sender, address(this), _amount);
        } else {
            oldwsEXO.safeTransferFrom(msg.sender, address(this), _amount);
            wAmount = _amount;
        }

        if (exoMigrated) {
            require(oldSupply >= oldEXO.totalSupply(), "OHMv1 minted");
            _send(wAmount, _to);
        } else {
            gEXO.mint(msg.sender, wAmount);
        }
    }

    // migrate all olympus tokens held
    function migrateAll(TYPE _to) external {
        require(!shutdown, "Shut down");

        uint256 exoBal = 0;
        uint256 sEXOBal = oldsEXO.balanceOf(msg.sender);
        uint256 wsEXOBal = oldwsEXO.balanceOf(msg.sender);

        if (oldEXO.balanceOf(msg.sender) > 0 && exoMigrated) {
            exoBal = oldEXO.balanceOf(msg.sender);
            oldEXO.safeTransferFrom(msg.sender, address(this), exoBal);
        }
        if (sEXOBal > 0) {
            oldsEXO.safeTransferFrom(msg.sender, address(this), sEXOBal);
        }
        if (wsEXOBal > 0) {
            oldwsEXO.safeTransferFrom(msg.sender, address(this), wsEXOBal);
        }

        uint256 wAmount = wsEXOBal.add(oldwsEXO.sOHMTowOHM(exoBal.add(sEXOBal)));
        if (exoMigrated) {
            require(oldSupply >= oldEXO.totalSupply(), "OHMv1 minted");
            _send(wAmount, _to);
        } else {
            gEXO.mint(msg.sender, wAmount);
        }
    }

    // send preferred token
    function _send(uint256 wAmount, TYPE _to) internal {
        if (_to == TYPE.WRAPPED) {
            gEXO.safeTransfer(msg.sender, wAmount);
        } else if (_to == TYPE.STAKED) {
            newStaking.unwrap(msg.sender, wAmount);
        } else if (_to == TYPE.UNSTAKED) {
            newStaking.unstake(msg.sender, wAmount, false, false);
        }
    }

    // bridge back to OHM, sOHM, or wsOHM
    function bridgeBack(uint256 _amount, TYPE _to) external {
        if (!exoMigrated) {
            gEXO.burn(msg.sender, _amount);
        } else {
            gEXO.safeTransferFrom(msg.sender, address(this), _amount);
        }

        uint256 amount = oldwsEXO.wOHMTosOHM(_amount);
        // error throws if contract does not have enough of type to send
        if (_to == TYPE.UNSTAKED) {
            oldEXO.safeTransfer(msg.sender, amount);
        } else if (_to == TYPE.STAKED) {
            oldsEXO.safeTransfer(msg.sender, amount);
        } else if (_to == TYPE.WRAPPED) {
            oldwsEXO.safeTransfer(msg.sender, _amount);
        }
    }

    /* ========== OWNABLE ========== */

    // halt migrations (but not bridging back)
    function halt() external onlyPolicy {
        require(!exoMigrated, "Migration has occurred");
        shutdown = !shutdown;
    }

    // withdraw backing of migrated OHM
    function defund(address reserve) external onlyGovernor {
        require(exoMigrated, "Migration has not begun");
        require(timelockEnd < block.number && timelockEnd != 0, "Timelock not complete");

        oldwsEXO.unwrap(oldwsEXO.balanceOf(address(this)));

        uint256 amountToUnstake = oldsEXO.balanceOf(address(this));
        oldsEXO.approve(address(oldStaking), amountToUnstake);
        oldStaking.unstake(amountToUnstake, false);

        uint256 balance = oldEXO.balanceOf(address(this));

        if (balance > oldSupply) {
            oldSupply = 0;
        } else {
            oldSupply -= balance;
        }

        uint256 amountToWithdraw = balance.mul(1e9);
        oldEXO.approve(address(oldTreasury), amountToWithdraw);
        oldTreasury.withdraw(amountToWithdraw, reserve);
        IERC20(reserve).safeTransfer(address(newTreasury), IERC20(reserve).balanceOf(address(this)));

        emit Defunded(balance);
    }

    // start timelock to send backing to new treasury
    function startTimelock() external onlyGovernor {
        require(timelockEnd == 0, "Timelock set");
        timelockEnd = block.number.add(timelockLength);

        emit TimelockStarted(block.number, timelockEnd);
    }

    // set gOHM address
    function setgOHM(address _gEXO) external onlyGovernor {
        require(address(gEXO) == address(0), "Already set");
        require(_gEXO != address(0), "Zero address: gEXO");

        gEXO = IgEXO(_gEXO);
    }

    // call internal migrate token function
    function migrateToken(address token) external onlyGovernor {
        _migrateToken(token, false);
    }

    /**
     *   @notice Migrate LP and pair with new OHM
     */
    function migrateLP(
        address pair,
        bool sushi,
        address token,
        uint256 _minA,
        uint256 _minB
    ) external onlyGovernor {
        uint256 oldLPAmount = IERC20(pair).balanceOf(address(oldTreasury));
        oldTreasury.manage(pair, oldLPAmount);

        IUniswapV2Router router = sushiRouter;
        if (!sushi) {
            router = uniRouter;
        }

        IERC20(pair).approve(address(router), oldLPAmount);
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            token,
            address(oldEXO),
            oldLPAmount,
            _minA,
            _minB,
            address(this),
            block.timestamp
        );

        newTreasury.mint(address(this), amountB);

        IERC20(token).approve(address(router), amountA);
        newEXO.approve(address(router), amountB);

        router.addLiquidity(
            token,
            address(newEXO),
            amountA,
            amountB,
            amountA,
            amountB,
            address(newTreasury),
            block.timestamp
        );
    }

    // Failsafe function to allow owner to withdraw funds sent directly to contract in case someone sends non-ohm tokens to the contract
    function withdrawToken(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyGovernor {
        require(tokenAddress != address(0), "Token address cannot be 0x0");
        require(tokenAddress != address(gEXO), "Cannot withdraw: gEXO");
        require(tokenAddress != address(oldEXO), "Cannot withdraw: old-EXO");
        require(tokenAddress != address(oldsEXO), "Cannot withdraw: old-sEXO");
        require(tokenAddress != address(oldwsEXO), "Cannot withdraw: old-wsEXO");
        require(amount > 0, "Withdraw value must be greater than 0");
        if (recipient == address(0)) {
            recipient = msg.sender; // if no address is specified the value will will be withdrawn to Owner
        }

        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 contractBalance = tokenContract.balanceOf(address(this));
        if (amount > contractBalance) {
            amount = contractBalance; // set the withdrawal amount equal to balance within the account.
        }
        // transfer the token from address of this contract
        tokenContract.safeTransfer(recipient, amount);
    }

    // migrate contracts
    function migrateContracts(
        address _newTreasury,
        address _newStaking,
        address _newEXO,
        address _newsEXO,
        address _reserve
    ) external onlyGovernor {
        require(!exoMigrated, "Already migrated");
        exoMigrated = true;
        shutdown = false;

        require(_newTreasury != address(0), "Zero address: Treasury");
        newTreasury = ITreasury(_newTreasury);
        require(_newStaking != address(0), "Zero address: Staking");
        newStaking = IStaking(_newStaking);
        require(_newEXO != address(0), "Zero address: EXO");
        newEXO = IERC20(_newEXO);

        oldSupply = oldEXO.totalSupply(); // log total supply at time of migration

        gEXO.migrate(_newStaking, _newsEXO); // change gOHM minter

        _migrateToken(_reserve, true); // will deposit tokens into new treasury so reserves can be accounted for

        _fund(oldsEXO.circulatingSupply()); // fund with current staked supply for token migration

        emit Migrated(_newStaking, _newTreasury);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    // fund contract with gOHM
    function _fund(uint256 _amount) internal {
        newTreasury.mint(address(this), _amount);
        newEXO.approve(address(newStaking), _amount);
        newStaking.stake(address(this), _amount, false, true); // stake and claim gEXO

        emit Funded(_amount);
    }

    /**
     *   @notice Migrate token from old treasury to new treasury
     */
    function _migrateToken(address token, bool deposit) internal {
        uint256 balance = IERC20(token).balanceOf(address(oldTreasury));

        uint256 excessReserves = oldTreasury.excessReserves();
        uint256 tokenValue = oldTreasury.valueOf(token, balance);

        if (tokenValue > excessReserves) {
            tokenValue = excessReserves;
            balance = excessReserves * 10**9;
        }

        oldTreasury.manage(token, balance);

        if (deposit) {
            IERC20(token).safeApprove(address(newTreasury), balance);
            newTreasury.deposit(balance, token, tokenValue);
        } else {
            IERC20(token).safeTransfer(address(newTreasury), balance);
        }
    }
}
