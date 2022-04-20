pragma solidity ^0.5.16;


interface IVaultV3 {

    function priceCumulative() external view returns (uint256);

    function oraclePrice() external view returns (uint256);

    function lastOraclePriceUpdateTimestamp() external view returns (uint256);
}
