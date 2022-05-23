pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthMagicSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_MAGIC_SLP = 0xB7E50106A5bd3Cf21AF210A755F9C8740890A8c9;
    uint256 public constant ETH_MAGIC_PID = 13;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = SUSHI;
        rewardTokens[1] = MAGIC;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_MAGIC_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_MAGIC_PID
        );
    }
}
