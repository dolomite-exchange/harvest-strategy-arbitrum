pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthDaiSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_DAI_SLP = 0x692a0B300366D1042679397e40f3d2cb4b8F7D30;
    uint256 public constant ETH_DAI_PID = 14;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = SUSHI;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_DAI_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_DAI_PID
        );
    }
}
