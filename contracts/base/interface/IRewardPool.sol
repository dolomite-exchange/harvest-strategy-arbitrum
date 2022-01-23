pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @dev Unifying interface with the Synthetix Reward Pool
 */
interface IRewardPool {

    function rewardToken() external view returns (address);

    function lpToken() external view returns (address);

    function duration() external view returns (uint256);

    function periodFinish() external view returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewardPerTokenStored() external view returns (uint256);

    function stake(uint256 amountWei) external;

    /**
     * The amount staked by the `holder`. Since this is 1 to 1, this is also the holder's share
     */
    function balanceOf(address holder) external view returns (uint256);

    // total shares & total lpTokens staked
    function totalSupply() external view returns (uint256);

    function withdraw(uint256 amountWei) external;

    function exit() external;

    function earned(address holder) external view returns (uint256);

    function getReward() external;

    function notifyRewardAmount(uint256 _amount) external;
}
