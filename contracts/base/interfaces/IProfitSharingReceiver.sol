pragma solidity ^0.5.16;


interface IProfitSharingReceiver {

    function withdrawTokens(address[] calldata _tokens) external;
}
