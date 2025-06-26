//+------------------------------------------------------------------+
//|                                       GridTradingEA_Enhanced.mq5 |
//|                                  Copyright 2025, Jaziel Trader    |
//|                             Enhanced version with safety features |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jaziel Trader"
#property link      "https://www.mql5.com"
#property version   "1.10"

#include "GridTradingConfig.mqh"

//--- Input parameters
input group "=== Trading Parameters ==="
input double InpLotSize = DEFAULT_LOT_SIZE;           // Lot size for each trade
input int InpProfitPoints = DEFAULT_PROFIT_POINTS;    // Profit target in points
input int InpGridSpacing = DEFAULT_GRID_SPACING;      // Grid spacing in points
input int InpMaxGridOrders = DEFAULT_MAX_GRID_ORDERS; // Maximum number of grid orders
input int InpMagicNumber = DEFAULT_MAGIC_NUMBER;      // Magic number for identification
input string InpTradeComment = "GridEA_Enhanced";     // Comment for trades

input group "=== Risk Management ==="
input bool InpEnableRiskManagement = true;           // Enable risk management
input double InpMaxDrawdownPercent = 20.0;           // Maximum drawdown percentage
input double InpMaxDailyLoss = 500.0;                // Maximum daily loss in account currency
input bool InpEnableSpreadFilter = true;             // Enable spread filter

input group "=== Advanced Settings ==="
input bool InpEnableTradingHours = ENABLE_TRADING_HOURS; // Enable trading hours filter
input bool InpEnableDetailedLogging = ENABLE_DETAILED_LOGGING; // Enable detailed logging
input bool InpAutoLotSizing = false;                 // Enable automatic lot sizing

//--- Global variables
datetime lastCandleTime = 0;
double averagePrice = 0;
int totalBuyOrders = 0;
double totalVolume = 0;
bool isInMarket = false;
double dailyStartBalance = 0;
datetime dailyStartTime = 0;
double maxDrawdown = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    LogMessage(2, "Grid Trading EA Enhanced - Initialization started");
    
    // Validate input parameters
    if(!ValidateInputs())
    {
        LogMessage(0, "Invalid input parameters. EA initialization failed.");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // Initialize daily tracking
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dailyStartTime = TimeCurrent();
    
    // Check account and symbol requirements
    if(!CheckAccountRequirements())
    {
        LogMessage(0, "Account requirements not met. EA initialization failed.");
        return(INIT_FAILED);
    }
    
    // Initialize variables
    CheckExistingPositions();
    
    LogMessage(2, StringFormat("EA initialized successfully - Symbol: %s, Lot: %.2f, Profit: %d pts, Grid: %d pts, Max Orders: %d", 
              _Symbol, InpLotSize, InpProfitPoints, InpGridSpacing, InpMaxGridOrders));
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    LogMessage(2, StringFormat("Grid Trading EA Enhanced deinitialized. Reason: %d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check daily reset
    CheckDailyReset();
    
    // Perform safety checks
    if(!PerformSafetyChecks()) return;
    
    // Check for new candle
    if(IsNewCandle())
    {
        LogMessage(3, StringFormat("New candle detected at: %s", TimeToString(TimeCurrent())));
        
        // Update market status
        CheckExistingPositions();
        
        // If not in market, start grid trading
        if(!isInMarket)
        {
            if(CanStartNewGrid())
            {
                StartGridTrading();
            }
        }
        else
        {
            // Update grid if needed
            ManageGrid();
        }
    }
    
    // Check for filled orders and manage positions
    CheckFilledOrders();
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(InpLotSize <= 0)
    {
        LogMessage(0, "Invalid lot size. Must be greater than 0.");
        return false;
    }
    
    if(InpProfitPoints <= 0)
    {
        LogMessage(0, "Invalid profit points. Must be greater than 0.");
        return false;
    }
    
    if(InpGridSpacing <= 0)
    {
        LogMessage(0, "Invalid grid spacing. Must be greater than 0.");
        return false;
    }
    
    if(InpMaxGridOrders <= 0 || InpMaxGridOrders > 100)
    {
        LogMessage(0, "Invalid max grid orders. Must be between 1 and 100.");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check account requirements                                        |
//+------------------------------------------------------------------+
bool CheckAccountRequirements()
{
    // Check minimum balance
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(balance < MIN_ACCOUNT_CURRENCY)
    {
        LogMessage(0, StringFormat("Insufficient account balance. Required: %.2f, Current: %.2f", 
                  MIN_ACCOUNT_CURRENCY, balance));
        return false;
    }
    
    // Check symbol validity
    if(!IsSymbolAllowed(_Symbol))
    {
        LogMessage(0, StringFormat("Symbol %s is not allowed for trading.", _Symbol));
        return false;
    }
    
    // Check trading permissions
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        LogMessage(0, "Trading is not allowed in terminal.");
        return false;
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        LogMessage(0, "Expert Advisors trading is not allowed.");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Perform safety checks                                            |
//+------------------------------------------------------------------+
bool PerformSafetyChecks()
{
    // Check trading hours
    if(InpEnableTradingHours && !IsTradingTimeAllowed())
    {
        return false;
    }
    
    // Check spread
    if(InpEnableSpreadFilter && !IsSpreadAcceptable(_Symbol))
    {
        LogMessage(1, StringFormat("Spread too high: %d points", 
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
        return false;
    }
    
    // Check risk management
    if(InpEnableRiskManagement)
    {
        if(!CheckDrawdownLimit() || !CheckDailyLossLimit())
        {
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check drawdown limit                                             |
//+------------------------------------------------------------------+
bool CheckDrawdownLimit()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double currentDrawdown = ((balance - equity) / balance) * 100;
    
    if(currentDrawdown > maxDrawdown)
        maxDrawdown = currentDrawdown;
    
    if(currentDrawdown > InpMaxDrawdownPercent)
    {
        LogMessage(0, StringFormat("Maximum drawdown exceeded: %.2f%% (limit: %.2f%%)", 
                  currentDrawdown, InpMaxDrawdownPercent));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                           |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyPL = currentBalance - dailyStartBalance;
    
    if(dailyPL < -InpMaxDailyLoss)
    {
        LogMessage(0, StringFormat("Daily loss limit exceeded: %.2f (limit: %.2f)", 
                  -dailyPL, InpMaxDailyLoss));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check daily reset                                                |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    MqlDateTime currentTime, startTime;
    TimeToStruct(TimeCurrent(), currentTime);
    TimeToStruct(dailyStartTime, startTime);
    
    if(currentTime.day != startTime.day)
    {
        // New day - reset tracking
        dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        dailyStartTime = TimeCurrent();
        maxDrawdown = 0;
        
        LogMessage(2, "New trading day started. Daily tracking reset.");
    }
}

//+------------------------------------------------------------------+
//| Check if new candle has formed                                   |
//+------------------------------------------------------------------+
bool IsNewCandle()
{
    datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0);
    
    if(currentCandleTime != lastCandleTime)
    {
        lastCandleTime = currentCandleTime;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if we can start a new grid                                 |
//+------------------------------------------------------------------+
bool CanStartNewGrid()
{
    // Check margin requirements for full grid
    double lotSize = InpAutoLotSizing ? GetAdjustedLotSize(InpLotSize) : InpLotSize;
    double marginRequired = (InpMaxGridOrders + 1) * lotSize * 
                           SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    
    if(!IsMarginSufficient(marginRequired))
    {
        LogMessage(1, "Insufficient margin for full grid trading.");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check existing positions and orders                             |
//+------------------------------------------------------------------+
void CheckExistingPositions()
{
    totalBuyOrders = 0;
    totalVolume = 0;
    averagePrice = 0;
    isInMarket = false;
    
    // Check positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                isInMarket = true;
                totalBuyOrders++;
                double volume = PositionGetDouble(POSITION_VOLUME);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                
                totalVolume += volume;
                averagePrice += openPrice * volume;
            }
        }
    }
    
    // Check pending orders
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderGetTicket(i))
        {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
               OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
            {
                isInMarket = true;
                totalBuyOrders++;
            }
        }
    }
    
    // Calculate average price
    if(totalVolume > 0)
    {
        averagePrice = averagePrice / totalVolume;
    }
    
    LogMessage(3, StringFormat("Market Status - In Market: %s, Total Orders: %d, Average Price: %.5f, Total Volume: %.2f", 
              isInMarket ? "true" : "false", totalBuyOrders, averagePrice, totalVolume));
}

//+------------------------------------------------------------------+
//| Start grid trading system                                        |
//+------------------------------------------------------------------+
void StartGridTrading()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    LogMessage(2, StringFormat("Starting grid trading at price: %.5f", currentPrice));
    
    // Get adjusted lot size if auto-sizing is enabled
    double lotSize = InpAutoLotSizing ? GetAdjustedLotSize(InpLotSize) : InpLotSize;
    
    // Place market order first
    if(PlaceMarketBuy(lotSize))
    {
        // Place grid of buy limit orders below current price
        for(int i = 1; i <= InpMaxGridOrders; i++)
        {
            double orderPrice = currentPrice - (InpGridSpacing * point * i);
            PlaceBuyLimitOrder(orderPrice, lotSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Place market buy order                                           |
//+------------------------------------------------------------------+
bool PlaceMarketBuy(double lotSize)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = NormalizeDouble(lotSize, 2);
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = MAX_SLIPPAGE_POINTS;
    request.magic = InpMagicNumber;
    request.comment = InpTradeComment + "_Market";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        LogMessage(2, StringFormat("Market buy order placed successfully. Ticket: %d, Volume: %.2f", 
                  result.order, request.volume));
        return true;
    }
    else
    {
        LogMessage(0, StringFormat("Failed to place market buy order. Error: %d", GetLastError()));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Place buy limit order                                            |
//+------------------------------------------------------------------+
bool PlaceBuyLimitOrder(double price, double lotSize)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = NormalizeDouble(lotSize, 2);
    request.type = ORDER_TYPE_BUY_LIMIT;
    request.price = NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    request.magic = InpMagicNumber;
    request.comment = InpTradeComment + "_Grid";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        LogMessage(3, StringFormat("Buy limit order placed at: %.5f, Volume: %.2f, Ticket: %d", 
                  request.price, request.volume, result.order));
        return true;
    }
    else
    {
        LogMessage(1, StringFormat("Failed to place buy limit order at: %.5f, Error: %d", 
                  price, GetLastError()));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Manage grid system                                               |
//+------------------------------------------------------------------+
void ManageGrid()
{
    // Check if we need to add more grid orders
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Find the lowest pending order
    double lowestOrderPrice = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderGetTicket(i))
        {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
               OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
            {
                double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
                if(lowestOrderPrice == 0 || orderPrice < lowestOrderPrice)
                {
                    lowestOrderPrice = orderPrice;
                }
            }
        }
    }
    
    // Add more orders if needed
    if(lowestOrderPrice > 0 && totalBuyOrders < InpMaxGridOrders + 1)
    {
        double nextOrderPrice = lowestOrderPrice - (InpGridSpacing * point);
        if(nextOrderPrice > 0)
        {
            double lotSize = InpAutoLotSizing ? GetAdjustedLotSize(InpLotSize) : InpLotSize;
            PlaceBuyLimitOrder(nextOrderPrice, lotSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Check for filled orders and update profit targets               |
//+------------------------------------------------------------------+
void CheckFilledOrders()
{
    static int lastPositionCount = 0;
    int currentPositionCount = 0;
    
    // Count current positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                currentPositionCount++;
            }
        }
    }
    
    // If new position was opened, update profit targets
    if(currentPositionCount > lastPositionCount)
    {
        LogMessage(2, "New position detected. Updating profit targets...");
        UpdateProfitTargets();
    }
    
    lastPositionCount = currentPositionCount;
}

//+------------------------------------------------------------------+
//| Update profit targets based on average price                    |
//+------------------------------------------------------------------+
void UpdateProfitTargets()
{
    CheckExistingPositions(); // Recalculate average price
    
    if(totalVolume == 0) return;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double targetPrice = averagePrice + (InpProfitPoints * point);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    LogMessage(2, StringFormat("Average Price: %.5f, Target Price: %.5f, Current Price: %.5f", 
              averagePrice, targetPrice, currentPrice));
    
    // Only place sell orders if current price is below target
    if(currentPrice < targetPrice)
    {
        // Remove existing sell orders
        RemoveAllSellOrders();
        
        // Place new sell limit order for total volume
        PlaceSellLimitOrder(targetPrice, totalVolume);
    }
}

//+------------------------------------------------------------------+
//| Remove all sell orders                                           |
//+------------------------------------------------------------------+
void RemoveAllSellOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderGetTicket(i))
        {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
               OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT)
            {
                MqlTradeRequest request;
                MqlTradeResult result;
                
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_REMOVE;
                request.order = OrderGetInteger(ORDER_TICKET);
                
                bool success = OrderSend(request, result);
                if(success)
                {
                    LogMessage(3, StringFormat("Sell order removed. Ticket: %d", request.order));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Place sell limit order                                           |
//+------------------------------------------------------------------+
bool PlaceSellLimitOrder(double price, double volume)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = NormalizeDouble(volume, 2);
    request.type = ORDER_TYPE_SELL_LIMIT;
    request.price = NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    request.magic = InpMagicNumber;
    request.comment = InpTradeComment + "_Profit";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        LogMessage(2, StringFormat("Sell limit order placed at: %.5f, Volume: %.2f, Ticket: %d", 
                  request.price, request.volume, result.order));
        return true;
    }
    else
    {
        LogMessage(0, StringFormat("Failed to place sell limit order at: %.5f, Error: %d", 
                  price, GetLastError()));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
    LogMessage(3, "Trade event detected. Checking positions...");
    CheckExistingPositions();
    
    // If all positions are closed, reset the system and remove all pending orders
    if(!isInMarket)
    {
        LogMessage(2, "All positions closed. System ready for new cycle.");
        totalBuyOrders = 0;
        totalVolume = 0;
        averagePrice = 0;
        DeleteAllPendingOrders();
    }
}

// Helper: Delete all pending orders for this symbol and magic number
void DeleteAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderGetTicket(i))
        {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
               (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT ||
                OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT))
            {
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                request.action = TRADE_ACTION_REMOVE;
                request.order = OrderGetInteger(ORDER_TICKET);
                bool success = OrderSend(request, result);
                if(success)
                {
                    LogMessage(2, StringFormat("Pending order removed. Ticket: %d", request.order));
                }
                else
                {
                    LogMessage(1, StringFormat("Failed to remove pending order. Ticket: %d, Error: %d", request.order, GetLastError()));
                }
            }
        }
    }
}
