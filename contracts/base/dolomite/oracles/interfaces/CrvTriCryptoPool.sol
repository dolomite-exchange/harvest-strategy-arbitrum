pragma solidity ^0.5.16;


interface CrvTriCryptoPool {

    function coins(uint256 i) external view returns (address);

    function D() external view returns (uint256);
}
