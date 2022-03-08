pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./TriCryptoStrategy.sol";


contract TriCryptoStrategyMainnet is TriCryptoStrategy, IMainnetStrategy {

    function initializeStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) public initializer {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = CRV;

        TriCryptoStrategy.initializeBaseStrategy(
            _storage,
            CRV_TRI_CRYPTO,
            _vault,
            CRV_TRI_CRYPTO_GAUGE,
            rewardTokens,
            _strategist,
            CRV_TRI_CRYPTO_POOL,
            WETH,
            /* depositArrayPosition = */ 2
        );
    }

}
