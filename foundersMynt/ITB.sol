// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============ Interfaces ============
interface ITB {
    function TREASURE_BOX() external view returns (address);
    function getTreasureBoxAssests() external view returns (uint256);
    function transferReward(address, uint256) external;
    function mint(
        address _receiver,
        uint256 _amount,
        address _contractAddress
    ) external;
    function treasureBoxMintedAmount() external view returns (uint256);
    function TREASURE_BOX_SUPPLY_CAP() external view returns (uint256);
    function treasureBoxAddress() external view returns (address);
}
