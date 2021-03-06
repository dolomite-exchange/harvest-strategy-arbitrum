pragma solidity ^0.5.16;


interface IProfitSharingReceiver {

    function governance() external view returns (address);

    function withdrawTokens(address[] calldata _tokens) external;
}
