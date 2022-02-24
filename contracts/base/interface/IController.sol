pragma solidity ^0.5.16;

interface IController {

    // ==================== Events ====================

    event SharePriceChangeLog(
        address indexed vault,
        address indexed strategy,
        uint256 oldSharePrice,
        uint256 newSharePrice,
        uint256 timestamp
    );

    // ==================== Functions ====================

    /**
     * An EOA can safely interact with the system no matter what. If you're using Metamask, you're using an EOA. Only
     * smart contracts may be affected by this grey list. This contract will not be able to ban any EOA from the system
     * even if an EOA is being added to the greyList, he/she will still be able to interact with the whole system as if
     * nothing happened. Only smart contracts will be affected by being added to the greyList. This grey list is only
     * used in VaultV3.sol, see the code there for reference
     */
    function greyList(address _target) external view returns (bool);

    function stakingWhiteList(address _target) external view returns (bool);

    function governance() external view returns (address);

    function addVaultAndStrategy(address _vault, address _strategy) external;

    function addVaultsAndStrategies(address[] calldata _vaults, address[] calldata _strategies) external;

    function doHardWork(address _vault) external;

    function salvage(address _token, uint256 amount) external;

    function salvageStrategy(address _strategy, address _token, uint256 amount) external;

    function notifyFee(address _underlying, uint256 fee) external;

    function feeRewardForwarder() external view returns (address);

    function setFeeRewardForwarder(address _value) external;

    function addHardWorker(address _worker) external;

    function universalLiquidator() external view returns (address);

    function nextImplementationDelay() external view returns (uint256);

    function profitSharingNumerator() external view returns (uint256);

    function profitSharingDenominator() external view returns (uint256);
}
