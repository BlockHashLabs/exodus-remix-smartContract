// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.5;

import "./SafeMath.sol";
import "./FixedPoint.sol";
import "./Address.sol";
import "./SafeERC20.sol";

import "./IERC20Metadata.sol";
import "./IERC20.sol";
import "./IBondingCalculator.sol";
import "./IUniswapV2ERC20.sol";
import "./IUniswapV2Pair.sol";

contract ExodusBondingCalculator is IBondingCalculator {
    using FixedPoint for *;
    using SafeMath for uint256;

    IERC20 internal immutable EXO;

    constructor(address _EXO) {
        require(_EXO != address(0), "Zero address: EXO");
        EXO = IERC20(_EXO);
    }

    function getKValue(address _pair) public view returns (uint256 k_) {
        uint256 token0 = IERC20Metadata(IUniswapV2Pair(_pair).token0()).decimals();
        uint256 token1 = IERC20Metadata(IUniswapV2Pair(_pair).token1()).decimals();
        uint256 decimals = token0.add(token1).sub(IERC20Metadata(_pair).decimals());

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(_pair).getReserves();
        k_ = reserve0.mul(reserve1).div(10**decimals);
    }

    function getTotalValue(address _pair) public view returns (uint256 _value) {
        _value = getKValue(_pair).sqrrt().mul(2);
    }

    function valuation(address _pair, uint256 amount_) external view override returns (uint256 _value) {
        uint256 totalValue = getTotalValue(_pair);
        uint256 totalSupply = IUniswapV2Pair(_pair).totalSupply();

        _value = totalValue.mul(FixedPoint.fraction(amount_, totalSupply).decode112with18()).div(1e18);
    }

    function markdown(address _pair) external view override returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(_pair).getReserves();

        uint256 reserve;
        if (IUniswapV2Pair(_pair).token0() == address(EXO)) {
            reserve = reserve1;
        } else {
            require(IUniswapV2Pair(_pair).token1() == address(EXO), "Invalid pair");
            reserve = reserve0;
        }
        return reserve.mul(2 * (10**IERC20Metadata(address(EXO)).decimals())).div(getTotalValue(_pair));
    }
}
