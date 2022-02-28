pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./TriCryptoStrategy.sol";


contract TriCryptoStrategyMainnet is TriCryptoStrategy, IMainnetStrategy {

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        TriCryptoStrategy.initializeBaseStrategy(
            _storage,
            CRV_TRI_CRYPTO,
            _vault,
            CRV_TRI_CRYPTO_GAUGE,
            CRV
        );
    }

}
