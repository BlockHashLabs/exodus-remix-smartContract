// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

import "./IERC20.sol";
import "./Ownable.sol";

contract ExoFaucet is Ownable {
    IERC20 public exo;

    constructor(address _exo) {
        exo = IERC20(_exo);
    }

    function setOhm(address _exo) external onlyOwner {
        exo = IERC20(_exo);
    }

    function dispense() external {
        exo.transfer(msg.sender, 1e9);
    }
}
