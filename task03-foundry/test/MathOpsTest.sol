// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MathOps.sol";

contract MathOpsTest is Test {
    MathOps math;
    
    function setUp() public {
        math = new MathOps();
    }

    // 基础运算测试
    function testAdd() public {
        assertEq(math.add(5, 3), 8);
    }

    function testSub() public {
        assertEq(math.sub(10, 4), 6);
    }

    function testSubRevert() public {
        vm.expectRevert("Underflow error");
        math.sub(3, 5);
    }

    // 优化版本测试
    function testOptimizedAdd() public {
        assertEq(math.optimizedAdd(5, 3), 8);
    }

    function testOptimizedSub() public {
        assertEq(math.optimizedSub(10, 4), 6);
    }

    function testOptimizedSubRevert() public {
        vm.expectRevert();
        math.optimizedSub(3, 5);
    }

    // 模糊测试
    function testAddFuzz(uint256 a, uint256 b) public {
        // 防止算术溢出(执行模糊测试，可能出现溢出，这样测试会报错终端测试)
        // 仅当不溢出时进行断言
        if (a <= type(uint256).max - b) {
            uint256 expected = a + b;
            assertEq(math.add(a, b), expected);
        }
    }

    function testOptimizedAddFuzz(uint256 a, uint256 b) public {
        // 优化版本允许溢出（自动取模）
        try math.optimizedAdd(a, b) returns (uint256 result) {
            unchecked {
                uint256 expected = a + b;
                assertEq(result, expected);
            }
        } catch {
            fail("optimizedAdd should not revert");
        }
    }

    // 差分测试：比较原始版本和优化版本
    function testDiffAdd(uint256 a, uint256 b) public {
        // 限制输入范围避免溢出
        vm.assume(a <= type(uint256).max / 2);
        vm.assume(b <= type(uint256).max / 2);
        
        uint256 originalResult = math.add(a, b);
        uint256 optimizedResult = math.optimizedAdd(a, b);
        
        assertEq(originalResult, optimizedResult, "Add results should match");
    }

    function testDiffSub(uint256 a, uint256 b) public {
        // 确保不会触发revert
        vm.assume(a >= b);
        
        uint256 originalResult = math.sub(a, b);
        uint256 optimizedResult = math.optimizedSub(a, b);
        
        assertEq(originalResult, optimizedResult, "Sub results should match");
    }
}