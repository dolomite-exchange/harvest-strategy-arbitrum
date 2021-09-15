pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";

contract SingleRewardDistributionRecipient is Ownable {
    address public rewardDistribution;

    constructor(address _rewardDistribution) public {
        rewardDistribution = _rewardDistribution;
    }

    function notifyRewardAmount(uint256 reward) external;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(address _rewardDistribution)
    external
    onlyOwner
    {
        rewardDistribution = _rewardDistribution;
    }
}
