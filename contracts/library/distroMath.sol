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

        if ( sum == 0 ){
            return distro;
        } else {
            for (uint256 i = 0; i < distro.length; i++) {
                distro[i] = Math.mulDiv(distro[i], distroNorm, sum);
            }
            sum = 0;
            uint256 index_max = 0;
            uint256 index_min = 0;
            uint256 value_max = 0;
            uint256 value_min = 2 * distroNorm;
            for (uint24 i = 0; i < distro.length; i++) {
                sum += distro[i];
                if (distro[i] > value_max && distro[i] > 0) {
                    value_max = distro[i];
                    index_max = i;
                }
                if (distro[i] < value_min && distro[i] > 0) {
                    value_min = distro[i];
                    index_min = i;
                }
            }
            if (sum < distroNorm) {
                distro[index_min] += distroNorm - sum;
            } else if (sum > distroNorm) {
                distro[index_max] -= sum - distroNorm;
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