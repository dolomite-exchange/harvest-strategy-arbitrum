pragma solidity ^0.5.16;

interface IMiniChefV2 {

  function deposit(uint256 _pid, uint256 _amount, address _to) external;
  function withdraw(uint256 _pid, uint256 _amount, address _to) external;
  function harvest(uint256 _pid, address _to) external;
  function withdrawAndHarvest(uint256 _pid, uint256 _amount, address _to) external;
  function userInfo(uint256 _pid, address _user) external view returns (uint256 _balance, int256 _rewardDebt);
  function poolInfo(uint256 _pid) external view returns (
    uint128 _accSushiPerShare,
    uint64 _lastRewardTimestamp,
    uint64 _allocPoint
  );
  function lpToken(uint256 _pid) external view returns (address);
  function pendingSushi(uint256 _pid, address _user) external view returns (uint256);
}
