// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * A range limit order is a strategy used to sell an asset within a specified price range.
 * For instance, suppose you anticipate the value of ETH to increase in the next week from its
 * current worth of 3000 DAI to a minimum of 4000 DAI.
 * In that case, you can create an ETH -> DAI limit order within the price range of 3000 -> 4000.
 * For example, you could create an order to sell 10 ETH within that price range.
 *
 * When someone places a bid for the entire limit order, they may purchase it all at once at
 * an average price of 3500 DAI. Alternatively, the limit order may be executed in portions.
 * For instance, the buyer might purchase 1 ETH for 3050 DAI, then another 1 ETH for 3150 DAI, and so on.
 *
 * Function of the changing price of makerAsset tokens in takerAsset tokens by the filling amount of makerAsset tokens in order:
 *      priceEnd - priceStart
 * y = ----------------------- * x + priceStart
 *           totalAmount
 */
contract RangeAmountCalculator {

    error IncorrectRange();

    modifier correctPrices(uint256 priceStart, uint256 priceEnd) {
        if (priceEnd <= priceStart) revert IncorrectRange();
        _;
    }

    function getRangeTakerAmount(
        uint256 priceStart,
        uint256 priceEnd,
        uint256 totalAmount,
        uint256 fillAmount,
        uint256 remainingMakingAmount
    ) public correctPrices(priceStart, priceEnd) pure returns(uint256) {
        uint256 alreadyFilledMakingAmount = totalAmount - remainingMakingAmount;
        /**
         * rangeTakerAmount = (
         *       f(makerAmountFilled) + f(makerAmountFilled + fillAmount)
         *   ) * fillAmount / 2 / 1e18
         *
         *  scaling to 1e18 happens to have better price accuracy
         */
        return (
            (priceEnd - priceStart) * (2 * alreadyFilledMakingAmount + fillAmount) / totalAmount +
            2 * priceStart
        ) * fillAmount / 2e18;
    }

    function getRangeMakerAmount(
        uint256 priceStart,
        uint256 priceEnd,
        uint256 totalLiquidity,
        uint256 takingAmount,
        uint256 remainingMakingAmount
    ) public correctPrices(priceStart, priceEnd) pure returns(uint256) {
        uint256 alreadyFilledMakingAmount = totalLiquidity - remainingMakingAmount;
        uint256 b = priceStart;
        uint256 k = (priceEnd - priceStart) * 1e18 / totalLiquidity;
        uint256 bDivK = priceStart * totalLiquidity / (priceEnd - priceStart);
        return (Math.sqrt(
            (
                b * bDivK +
                alreadyFilledMakingAmount * (2 * b + k * alreadyFilledMakingAmount / 1e18) +
                2 * takingAmount * 1e18
            ) / k * 1e18
        ) - bDivK) - alreadyFilledMakingAmount;
    }
}
