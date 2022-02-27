pragma solidity ^0.5.16;


interface CrvToken {

    function totalSupply() external view returns (uint);

    function minter() external view returns (address);
}
