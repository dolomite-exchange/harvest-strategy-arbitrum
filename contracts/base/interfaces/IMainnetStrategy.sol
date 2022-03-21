pragma solidity ^0.5.16;


interface IMainnetStrategy {

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external;
}
