pragma solidity ^0.5.16;

import "./GovernableStorage.sol";


contract ControllableStorage is GovernableStorage {

    function initializeControllable(address _storage) public initializer {
        GovernableStorage.initializeGovernable(_storage);
    }

    modifier onlyController() {
        require(store.isController(msg.sender), "Not a controller");
        _;
    }

    modifier onlyControllerOrGovernance(){
        require((store.isController(msg.sender) || store.isGovernance(msg.sender)),
            "The caller must be controller or governance");
        _;
    }

    function controller() public view returns (address) {
        return store.controller();
    }
}
