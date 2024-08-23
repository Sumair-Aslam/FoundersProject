// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============ Interfaces ============
interface IFMYNT {
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function TREASURE_BOX() external view returns (address);
    function getTreasureBoxAssests() external view returns (uint256);
    function transferReward(address, uint256) external;
    function treasureBoxMintedAmount() external view returns (uint256);
    function TREASURE_BOX_SUPPLY_CAP() external view returns (uint256);
    function treasureBoxAddress() external view returns (address);
    function stakeIntoTreasurePool(address, uint256) external returns (bool);
}
