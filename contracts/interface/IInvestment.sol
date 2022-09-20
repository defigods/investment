//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IInvestment {
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external;
}
