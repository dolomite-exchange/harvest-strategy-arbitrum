pragma solidity ^0.5.16;

import "../inheritance/ControllableInit.sol";


contract IStrategy {

    /// @notice declared as public so child contract can call it
    function isUnsalvageableToken(address token) public view returns (bool);

    function salvageToken(address recipient, address token, uint amount) external;

    function governance() external view returns (address);

    function controller() external view returns (address);

    function underlying() external view returns (address);

    function vault() external view returns (address);

    function withdrawAllToVault() external;

    function withdrawToVault(uint256 _amount) external;

    function investedUnderlyingBalance() external view returns (uint256); // itsNotMuch()

    function doHardWork() external;

    function depositArbCheck() external view returns (bool);
}
