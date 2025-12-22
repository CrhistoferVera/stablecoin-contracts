// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Prueba{

    uint number;

    function getNumber() public view returns (uint){
        return number;
    }

    function setNumber(uint _number) public{
        number=_number;
    }

}