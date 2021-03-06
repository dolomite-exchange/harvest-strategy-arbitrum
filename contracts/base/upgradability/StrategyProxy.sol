pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/upgradeability/BaseUpgradeabilityProxy.sol";
import "../interfaces/IUpgradeSource.sol";


contract StrategyProxy is BaseUpgradeabilityProxy {

  constructor(address _implementation) public {
    _setImplementation(_implementation);
  }

  /**
   * If the timer has elapsed and there is a schedule upgrade, Governance can upgrade the strategy.
   */
  function upgrade() external {
    (bool should, address newImplementation) = IUpgradeSource(address(this)).shouldUpgrade();
    require(should, "Upgrade not scheduled");
    _upgradeTo(newImplementation);

    // the finalization needs to be executed on itself to update the storage of this proxy
    // it also needs to be invoked by the governance, not by address(this), so delegatecall is needed
    (bool success,) = address(this).delegatecall(abi.encodeWithSignature("finalizeUpgrade()"));

    require(success, "Could not finalize the upgrade");
  }

  function implementation() external view returns (address) {
    return _implementation();
  }
}
