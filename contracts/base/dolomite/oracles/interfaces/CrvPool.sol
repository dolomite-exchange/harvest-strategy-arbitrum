pragma solidity ^0.5.16;


interface CrvPool {

    function coins(uint i) external view returns (address);

    function D() external view returns (uint);
}
