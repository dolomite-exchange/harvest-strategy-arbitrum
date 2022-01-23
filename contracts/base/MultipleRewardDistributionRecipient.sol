// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";

contract MultipleRewardDistributionRecipient is Ownable {

    mapping (address => bool) public rewardDistribution;

    constructor(address[] memory _rewardDistributions) public {
        // NotifyHelper
        rewardDistribution[0xE20c31e3d08027F5AfACe84A3A46B7b3B165053c] = true;

        // FeeRewardForwarderV5
        rewardDistribution[0x153C544f72329c1ba521DDf5086cf2fA98C86676] = true;

        for(uint256 i = 0; i < _rewardDistributions.length; i++) {
            rewardDistribution[_rewardDistributions[i]] = true;
        }
    }

    function notifyTargetRewardAmount(address rewardToken, uint256 reward) external;

    modifier onlyRewardDistribution() {
        require(rewardDistribution[msg.sender], "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(
        address[] calldata _newRewardDistribution,
        bool _flag
    )
    external
    onlyOwner
    {
        for(uint256 i = 0; i < _newRewardDistribution.length; i++){
            rewardDistribution[_newRewardDistribution[i]] = _flag;
        }
    }
}
