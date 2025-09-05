// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MathOps {
    // 原始实现
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) public pure returns (uint256) {
        require(a >= b, "Underflow error");
        return a - b;
    }

    // 优化版本
    function optimizedAdd(uint256 a, uint256 b) public pure returns (uint256) {
        // 策略1：使用unchecked减少溢出检查，出现溢出则直接返回截断后的错误结果(在 Solidity 0.8.0 及以上版本中，​​所有算术运算默认会自动检查溢出​​)
        unchecked { return a + b; }
    }

    function optimizedSub(uint256 a, uint256 b) public pure returns (uint256) {
        // 策略2：内联require检查
        if (a < b) revert("Underflow error");   // if + revert 对比require少量节省gas
        unchecked { return a - b; }             // 不进行溢出检查大量节省gas
    }
}