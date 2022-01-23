pragma solidity ^0.5.16;

interface IVault {

    function initializeVault(
        address _storage,
        address _underlying,
        uint256 _toInvestNumerator,
        uint256 _toInvestDenominator
    ) external;

    function balanceOf(address _holder) external view returns (uint256);

    function underlyingBalanceInVault() external view returns (uint256);

    function underlyingBalanceWithInvestment() external view returns (uint256);

    function governance() external view returns (address);

    function controller() external view returns (address);

    function underlying() external view returns (address);

    function strategy() external view returns (address);

    function setStrategy(address _strategy) external;

    function announceStrategyUpdate(address _strategy) external;

    function setVaultFractionToInvest(uint256 _numerator, uint256 _denominator) external;

    function deposit(uint256 _amountWei) external;

    function depositFor(uint256 _amountWei, address _holder) external;

    function withdrawAll() external;

    function withdraw(uint256 _numberOfShares) external;

    function getPricePerFullShare() external view returns (uint256);

    function underlyingBalanceWithInvestmentForHolder(address _holder) view external returns (uint256);

    /**
     * This should be callable only by the controller (by the hard worker) or by governance
     */
    function doHardWork() external;
}
