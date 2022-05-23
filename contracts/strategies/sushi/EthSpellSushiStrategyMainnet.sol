pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthSpellSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_SPELL_SLP = 0x8f93Eaae544e8f5EB077A1e09C1554067d9e2CA8;
    uint256 public constant ETH_SPELL_PID = 11;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = SUSHI;
        rewardTokens[1] = SPELL;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_SPELL_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_SPELL_PID
        );
    }
}
