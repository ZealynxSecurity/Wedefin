// SPDX-License-Identifier: MIT
//Just a library with distribution math operations
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/math/Math.sol";

library distroMath {

    uint256 public constant distroNorm = 10 ** 6; // @audit constants should be uppercase

    // Normalize the distribution of assets to distroNorm
    function normalize(uint256[] memory distro) internal pure returns (uint256[] memory) {
        uint256 sum = 0;
        for (uint256 i = 0; i < distro.length; i++) {
            sum += distro[i];
        }

        if (sum == 0) {
            return distro;
        } else {
            for (uint256 i = 0; i < distro.length; i++) {
                distro[i] = Math.mulDiv(distro[i], distroNorm, sum);
            }
        }

        return distro;
    }

    // Helper function to check if an address is in the newAssets array
    function isInNewAssets(address asset, address[] memory newAssets) internal pure returns (bool) {
        for (uint256 i = 0; i < newAssets.length; i++) {
            if (newAssets[i] == asset) {
                return true;
            }
        }
        return false;
    }

}