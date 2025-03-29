// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SuperchainERC20} from "interop-lib/src/SuperchainERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";

contract L2NativeSuperchainERC20 is SuperchainERC20, Ownable {
  string private _name;
  string private _symbol;
  uint8 private immutable _decimals;
  IERC20 private immutable _nativeToken;

  event Deposit(address indexed from, uint256 amount);
  event Withdrawal(address indexed to, uint256 amount);

  constructor(
    address owner_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address nativeToken_
  ) {
    _name = name_;
    _symbol = symbol_;
    _decimals = decimals_;
    _nativeToken = IERC20(nativeToken_);
    _initializeOwner(owner_);
  }

  function name() public view virtual override returns (string memory) {
    return _name;
  }

  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function mintTo(address to_, uint256 amount_) external onlyOwner {
    _mint(to_, amount_);
  }

  // Deposit native tokens to receive wrapped tokens
  function deposit(uint256 amount) public payable {
    _mint(msg.sender, amount);
    _nativeToken.transferFrom(msg.sender, address(this), amount);
    emit Deposit(msg.sender, amount);
  }

  // Withdraw native tokens by burning wrapped tokens
  function withdraw(uint256 amount) public {
    require(balanceOf(msg.sender) >= amount, "Insufficient balance");
    _burn(msg.sender, amount);
    _nativeToken.transfer(msg.sender, amount);
    emit Withdrawal(msg.sender, amount);
  }
}
