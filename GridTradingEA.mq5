//+------------------------------------------------------------------+
//|                                                 GridTradingEA.mq5 |
//|                                  Copyright 2025, Jaziel Trader    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jaziel Trader"
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Input parameters
input double LotSize = 0.1;           // Lot size for each trade
input int ProfitPoints = 200;         // Profit target in points
input int GridSpacing = 200;          // Grid spacing in points
input int MaxGridOrders = 20;         // Maximum number of grid orders
input int MagicNumber = 123456;       // Magic number for identification
input string TradeComment = "GridEA"; // Comment for trades

//--- Global variables
datetime lastCandleTime = 0;
double averagePrice = 0;
int totalBuyOrders = 0;
double totalVolume = 0;
bool isInMarket = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Grid Trading EA initialized");
    Print("Lot Size: ", LotSize);
    Print("Profit Points: ", ProfitPoints);
    Print("Grid Spacing: ", GridSpacing);
    Print("Max Grid Orders: ", MaxGridOrders);
    
    // Initialize variables
    CheckExistingPositions();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Grid Trading EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new candle
    if(IsNewCandle())
    {
        Print("New candle detected at: ", TimeToString(TimeCurrent()));
        
        // Update market status
        CheckExistingPositions();
        
        // If not in market, start grid trading
        if(!isInMarket)
        {
            StartGridTrading();
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
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
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
               OrderGetInteger(ORDER_MAGIC) == MagicNumber &&
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
    
    Print("Market Status - In Market: ", isInMarket, ", Total Orders: ", totalBuyOrders, 
          ", Average Price: ", averagePrice, ", Total Volume: ", totalVolume);
}

//+------------------------------------------------------------------+
//| Start grid trading system                                        |
//+------------------------------------------------------------------+
void StartGridTrading()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    Print("Starting grid trading at price: ", NormalizeDouble(currentPrice, digits));
    
    // Place market order first
    if(PlaceMarketBuy())
    {
        // Place grid of buy limit orders below current price
        for(int i = 1; i <= MaxGridOrders; i++)
        {
            double orderPrice = currentPrice - (GridSpacing * point * i);
            PlaceBuyLimitOrder(orderPrice);
        }
    }
}

//+------------------------------------------------------------------+
//| Place market buy order                                           |
//+------------------------------------------------------------------+
bool PlaceMarketBuy()
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = TradeComment + "_Market";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        Print("Market buy order placed successfully. Ticket: ", result.order);
        return true;
    }
    else
    {
        Print("Failed to place market buy order. Error: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Place buy limit order                                            |
//+------------------------------------------------------------------+
bool PlaceBuyLimitOrder(double price)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_BUY_LIMIT;
    request.price = NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    request.magic = MagicNumber;
    request.comment = TradeComment + "_Grid";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        Print("Buy limit order placed at: ", request.price, " Ticket: ", result.order);
        return true;
    }
    else
    {
        Print("Failed to place buy limit order at: ", price, " Error: ", GetLastError());
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
               OrderGetInteger(ORDER_MAGIC) == MagicNumber &&
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
    if(lowestOrderPrice > 0 && totalBuyOrders < MaxGridOrders + 1)
    {
        double nextOrderPrice = lowestOrderPrice - (GridSpacing * point);
        if(nextOrderPrice > 0)
        {
            PlaceBuyLimitOrder(nextOrderPrice);
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
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                currentPositionCount++;
            }
        }
    }
    
    // If new position was opened, update profit targets
    if(currentPositionCount > lastPositionCount)
    {
        Print("New position detected. Updating profit targets...");
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
    double targetPrice = averagePrice + (ProfitPoints * point);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    Print("Average Price: ", averagePrice, ", Target Price: ", targetPrice, ", Current Price: ", currentPrice);
    
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
               OrderGetInteger(ORDER_MAGIC) == MagicNumber &&
               OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT)
            {
                MqlTradeRequest request;
                MqlTradeResult result;
                
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_REMOVE;
                request.order = OrderGetInteger(ORDER_TICKET);
                
                OrderSend(request, result);
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
    request.magic = MagicNumber;
    request.comment = TradeComment + "_Profit";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        Print("Sell limit order placed at: ", request.price, " Volume: ", request.volume, " Ticket: ", result.order);
        return true;
    }
    else
    {
        Print("Failed to place sell limit order at: ", price, " Error: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
    Print("Trade event detected. Checking positions...");
    CheckExistingPositions();
    
    // If all positions are closed, reset the system
    if(!isInMarket)
    {
        Print("All positions closed. System ready for new cycle.");
        totalBuyOrders = 0;
        totalVolume = 0;
        averagePrice = 0;
    }
}
