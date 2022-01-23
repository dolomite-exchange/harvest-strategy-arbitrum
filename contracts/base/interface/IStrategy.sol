pragma solidity ^0.5.16;

import "../inheritance/ControllableInit.sol";


contract IStrategy is ControllableInit {

    function isUnsalvageableToken(address tokens) external view returns (bool);

    function governance() external view returns (address);

    function controller() external view returns (address);

    function underlying() external view returns (address);

    function vault() external view returns (address);

    function withdrawAllToVault() external;

    function withdrawToVault(uint256 _amount) external;

    function investedUnderlyingBalance() external view returns (uint256); // itsNotMuch()

    /**
     * Governance or Controller can claim coins that are somehow transferred into the contract. Note that they cannot
     * come in take away coins that are used and defined in the strategy itself. Those are protected by the
     * `isUnsalvageableToken` function. To check, see where those are being flagged.
     */
    function salvage(address recipient, address token, uint256 amount) external onlyControllerOrGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!isUnsalvageableToken[token], "token is defined as not salvageable");
        IERC20(token).safeTransfer(recipient, amount);
    }

    function doHardWork() external;

    function depositArbCheck() external view returns (bool);
}
