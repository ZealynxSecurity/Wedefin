// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol"; // Para la función `bound`
import "../contracts/library/distroMath.sol"; // Asegúrate de que la ruta es correcta

contract distroMathTest is Test {

    using distroMath for uint256[];

    uint256 constant DISTRO_NORM = 10 ** 6;

    function testNormalizeWithNonZeroSum() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = 1;
        distro[1] = 1;
        distro[2] = 1;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithZeroSum() public {
        uint256[] memory distro = new uint256[](3);

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, 0, "Sum should be zero");
    }

    function testNormalizeWithLargeValues() public {
        uint256[] memory distro = new uint256[](2);
        distro[0] = 2**128;
        distro[1] = 2**128;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithEdgeCaseValues() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = DISTRO_NORM;
        distro[1] = 0;
        distro[2] = 0;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
        assertEq(normalizedDistro[0], DISTRO_NORM, "First element should be DISTRO_NORM");
        assertEq(normalizedDistro[1], 0, "Second element should be 0");
        assertEq(normalizedDistro[2], 0, "Third element should be 0");
    }

    function testNormalizeDistributionPrecision() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = 1;
        distro[1] = 2;
        distro[2] = 3;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");

        uint256 expectedFirst = DISTRO_NORM * distro[0] / (distro[0] + distro[1] + distro[2]);
        uint256 expectedSecond = DISTRO_NORM * distro[1] / (distro[0] + distro[1] + distro[2]);
        uint256 expectedThird = DISTRO_NORM * distro[2] / (distro[0] + distro[1] + distro[2]);

        assertEq(normalizedDistro[0], expectedFirst, "First element should be correctly normalized");
        assertEq(normalizedDistro[1], expectedSecond, "Second element should be correctly normalized");
        assertEq(normalizedDistro[2], expectedThird, "Third element should be correctly normalized");
    }

    function testNormalizeWithMixedValues() public { //@audit
        uint256[] memory distro = new uint256[](5);
        distro[0] = 1;
        distro[1] = 2;
        distro[2] = 3;
        distro[3] = 4;
        distro[4] = 5;

        uint256 originalSum = 1 + 2 + 3 + 4 + 5; 

        // Normalizamos los valores
        uint256[] memory normalizedDistro = distro.normalize();

        // Calculamos la suma total después de la normalización
        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        // Emitimos logs para depuración
        emit log_named_uint("Total Sum After Normalization", sum);
        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");

        // Verificamos que cada elemento normalizado esté aproximadamente correcto
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            // Calculamos el valor esperado basado en la distribución normalizada
            uint256 expected = Math.mulDiv(distro[i], DISTRO_NORM, originalSum);
            emit log_named_uint("Original Value", distro[i]);
            emit log_named_uint("Normalized Value", normalizedDistro[i]);
            emit log_named_uint("Expected Value", expected);
            assertApproxEqAbs(normalizedDistro[i], expected, 1, "Each element should be approximately normalized");
        }
    }



    function testNormalizeWithMaxUint256Values() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = type(uint256).max;
        distro[1] = type(uint256).max;
        distro[2] = type(uint256).max;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithLargeAndSmallValues() public {
        uint256[] memory distro = new uint256[](4);
        distro[0] = type(uint256).max / 2;
        distro[1] = 1;
        distro[2] = 1;
        distro[3] = 1;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }


function testNormalizeWithUnequalValuesAndZero() public {
    uint256[] memory distro = new uint256[](4);
    distro[0] = 10;
    distro[1] = 0;
    distro[2] = 20;
    distro[3] = 70;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
}


function testNormalizeWithValuesNearDistroNorm() public {
    uint256[] memory distro = new uint256[](3);
    distro[0] = DISTRO_NORM / 2;
    distro[1] = DISTRO_NORM / 3;
    distro[2] = DISTRO_NORM / 6;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
}


function testNormalizeWithExactDistroNormValues() public {
    uint256[] memory distro = new uint256[](2);
    distro[0] = DISTRO_NORM / 2;
    distro[1] = DISTRO_NORM / 2;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
}


function testNormalizeWithAllOnes() public {
    uint256[] memory distro = new uint256[](5);
    distro[0] = 1;
    distro[1] = 1;
    distro[2] = 1;
    distro[3] = 1;
    distro[4] = 1;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
}


function testNormalizeWithExtremeAndZeroValues() public {
    uint256[] memory distro = new uint256[](4);
    distro[0] = type(uint256).max;
    distro[1] = 0;
    distro[2] = 1;
    distro[3] = 0;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
}


function testNormalizeWithSingleValue() public {
    uint256[] memory distro = new uint256[](1);
    distro[0] = 42;

    uint256[] memory normalizedDistro = distro.normalize();

    assertEq(normalizedDistro[0], DISTRO_NORM, "Single element should be normalized to DISTRO_NORM");
}


function testSumOfNormalizedValues() public {
    uint256[] memory distro = new uint256[](4);
    distro[0] = 10;
    distro[1] = 20;
    distro[2] = 30;
    distro[3] = 40;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum of normalized values should be equal to DISTRO_NORM");
}

function testRelativeProportions() public {
    uint256[] memory distro = new uint256[](3);
    distro[0] = 100;
    distro[1] = 200;
    distro[2] = 700;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 totalOriginal = 100 + 200 + 700;

    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        uint256 expected = Math.mulDiv(distro[i], DISTRO_NORM, totalOriginal);
        emit log_named_uint("Original Value", distro[i]);
        emit log_named_uint("Normalized Value", normalizedDistro[i]);
        emit log_named_uint("Expected Value", expected);
        emit log_named_uint("Difference", normalizedDistro[i] > expected ? normalizedDistro[i] - expected : expected - normalizedDistro[i]);
        assertApproxEqAbs(normalizedDistro[i], expected, 1, "Relative proportions should be maintained");
    }
}



function testNormalizationWithZeros() public {
    uint256[] memory distro = new uint256[](4);
    distro[0] = 0;
    distro[1] = 50;
    distro[2] = 50;
    distro[3] = 0;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum of normalized values should be equal to DISTRO_NORM");
}

function testNormalizationWithLargeValues() public {
    uint256[] memory distro = new uint256[](2);
    distro[0] = type(uint256).max / 2;
    distro[1] = type(uint256).max / 2;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum of normalized values should be equal to DISTRO_NORM");
}

function testNoNegativeValues() public {
    uint256[] memory distro = new uint256[](4);
    distro[0] = 1;
    distro[1] = 2;
    distro[2] = 3;
    distro[3] = 4;

    uint256[] memory normalizedDistro = distro.normalize();

    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        assertGt(normalizedDistro[i], 0, "Normalized value should not be negative");
    }
}


function testAlreadyNormalized() public { //@audit
    uint256[] memory distro = new uint256[](3);
    distro[0] = DISTRO_NORM / 3;
    distro[1] = DISTRO_NORM / 3;
    distro[2] = DISTRO_NORM / 3;

    uint256[] memory normalizedDistro = distro.normalize();

    uint256 sum = 0;
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        sum += normalizedDistro[i];
    }

    assertEq(sum, DISTRO_NORM, "Sum of normalized values should be equal to DISTRO_NORM");
    for (uint256 i = 0; i < normalizedDistro.length; i++) {
        assertEq(normalizedDistro[i], DISTRO_NORM / 3, "Values should remain the same if already normalized");
    }
}

function testInputValuesNotChanged() public { //@audit
    uint256[] memory distro = new uint256[](3);
    distro[0] = 100;
    distro[1] = 200;
    distro[2] = 300;

    uint256[] memory originalDistro = new uint256[](3);
    for (uint256 i = 0; i < distro.length; i++) {
        originalDistro[i] = distro[i];
    }

    distro.normalize();

    for (uint256 i = 0; i < distro.length; i++) {
        assertEq(distro[i], originalDistro[i], "Original values should not be changed");
    }
}

}
