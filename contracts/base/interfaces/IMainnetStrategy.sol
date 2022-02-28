pragma solidity ^0.5.16;


interface IMainnetStrategy {

    function initializeStrategy(
        address _storage,
        address _vault
    ) external;
}
