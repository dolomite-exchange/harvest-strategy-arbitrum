pragma solidity ^0.5.16;


interface SNXRewardInterface {

    function withdraw(uint _amount) external;

    function getReward() external;

    function stake(uint _amount) external;

    function balanceOf(address _account) external view returns (uint256);

    function earned(address _account) external view returns (uint256);

    function exit() external;
}
