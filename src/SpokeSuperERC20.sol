// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SuperchainERC20} from "interop-lib/src/SuperchainERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

contract SpokeSuperERC20 is SuperchainERC20, Ownable {
    string private NAME;
    string private SYMBOL;
    uint8 private immutable DECIMALS;

    constructor(address _owner, string memory _name, string memory _symbol, uint8 _decimals) {
        _name = _name;
        _symbol = _symbol;
        _decimals = _decimals;

        _initializeOwner(_owner);
    }

    function name() public view virtual override returns (string memory) {
        return NAME;
    }

    function symbol() public view virtual override returns (string memory) {
        return SYMBOL;
    }

    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }

    function mint(address _to, uint256 _amount) external {
		_checkOwner();
        _mint(_to, _amount);
    }
}
