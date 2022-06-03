pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthMimSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_MIM_SLP = 0xb6DD51D5425861C808Fd60827Ab6CFBfFE604959;
    uint256 public constant ETH_MIM_PID = 9;

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
            ETH_MIM_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_MIM_PID
        );
    }
}
