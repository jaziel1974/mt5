# Grid Trading Expert Advisor (MT5)

## Overview
This Expert Advisor implements a grid trading strategy based on your specific requirements. It automatically manages buy orders with a grid system and profit targets.

## Trading Strategy

### Core Rules
1. **New Candle Trigger**: At each new 1-minute candle, if not currently in the market, the EA will:
   - Place 1 market buy order
   - Place 20 additional buy limit orders spaced 200 points below each other

2. **Grid System**: 
   - Orders are placed 200 points apart
   - Maximum of 20 grid orders below the initial entry
   - Each order uses the same lot size

3. **Profit Target Management**:
   - Each trade targets 200 points of profit
   - When new orders are filled, the average price is recalculated
   - Profit target is adjusted to maintain 200 points from the new average price
   - Sell orders are only placed if current price is below the calculated profit target

4. **Dynamic Averaging**:
   - As the market moves down and grid orders are triggered
   - The EA recalculates the average entry price
   - Adjusts the profit target accordingly

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| LotSize | 0.1 | Lot size for each individual trade |
| ProfitPoints | 200 | Profit target in points |
| GridSpacing | 200 | Distance between grid orders in points |
| MaxGridOrders | 20 | Maximum number of grid orders to place |
| MagicNumber | 123456 | Unique identifier for EA trades |
| TradeComment | "GridEA" | Comment added to all trades |

## How It Works

### Initial Entry
1. When a new 1-minute candle forms and the EA is not in the market:
   - Places 1 market buy order at current price
   - Places 20 buy limit orders at 200, 400, 600, ... 4000 points below

### Order Management
2. When grid orders are triggered:
   - Calculates new average price based on all open positions
   - Removes existing profit target orders
   - Places new sell limit order for total volume at average price + 200 points
   - Only if current market price is below the profit target

### Profit Taking
3. When the market reaches the profit target:
   - All positions are closed with 200 points profit
   - System resets and waits for next new candle to restart

## Installation Instructions

1. Copy `GridTradingEA.mq5` to your MT5 `Experts` folder:
   ```
   C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Terminal_ID]\MQL5\Experts\
   ```

2. Compile the EA in MetaEditor:
   - Open MetaEditor
   - Open the GridTradingEA.mq5 file
   - Press F7 or click Compile
   - Ensure no errors in compilation

3. Attach to chart:
   - Open a 1-minute chart of your desired instrument
   - Drag the EA from Navigator to the chart
   - Configure input parameters
   - Enable Expert Advisors and Auto Trading

## Risk Management

### Important Considerations
- **High Risk Strategy**: This is a grid trading system that can accumulate many positions
- **Margin Requirements**: Ensure sufficient margin for up to 21 positions (1 market + 20 grid)
- **Drawdown Potential**: Large drawdowns possible if market trends strongly downward
- **Testing Recommended**: Test thoroughly on demo account first

### Recommended Settings
- Start with small lot sizes (0.01 - 0.1)
- Monitor margin levels closely
- Consider maximum drawdown limits
- Test on stable, ranging markets first

## Monitoring and Logs

The EA provides detailed logging:
- New candle detection
- Order placement confirmations
- Average price calculations
- Profit target updates
- Position management events

Check the MT5 Journal and Experts tabs for detailed information.

## Customization Options

You can modify the following aspects:
- Grid spacing (currently 200 points)
- Number of grid levels (currently 20)
- Profit target (currently 200 points)
- Lot size progression (currently equal lots)
- Timeframe trigger (currently 1-minute)

## Troubleshooting

### Common Issues
1. **EA not placing orders**: 
   - Check if Expert Advisors are enabled
   - Verify Auto Trading is active
   - Check margin requirements

2. **Orders not triggered**:
   - Verify symbol point value
   - Check minimum distance requirements
   - Ensure sufficient account balance

3. **Profit targets not updating**:
   - Check if positions have sufficient profit
   - Verify current price vs target price logic

### Support
- Check MT5 Journal for error messages
- Verify account permissions for Expert Advisors
- Test on demo account first

## Disclaimer
This EA is for educational and research purposes. Trading involves risk of loss. Always test strategies thoroughly before using real money. Past performance does not guarantee future results.
