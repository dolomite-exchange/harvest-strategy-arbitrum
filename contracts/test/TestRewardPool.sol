pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";


contract TestRewardPool {
    using SafeERC20 for IERC20;

    address public depositToken;
    address public rewardToken;

    constructor(
        address _depositToken,
        address _rewardToken
    ) public {
        depositToken = _depositToken;
        rewardToken = _rewardToken;
    }

    function depositIntoPool(uint _amount) public {
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdrawFromPool(uint _amount) public {
        IERC20(depositToken).safeTransfer(msg.sender, _amount);
    }

    function claimRewards() public {
        IERC20(rewardToken).safeTransfer(msg.sender, IERC20(rewardToken).balanceOf(address(this)));
    }

}
