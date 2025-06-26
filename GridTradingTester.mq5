//+------------------------------------------------------------------+
//|                                           GridTradingTester.mq5 |
//|                                  Copyright 2025, Jaziel Trader    |
//|                              Testing script for Grid Trading EA   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jaziel Trader"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- Input parameters for testing
input group "=== Test Parameters ==="
input double TestLotSize = 0.01;          // Test lot size
input int TestProfitPoints = 200;         // Test profit points
input int TestGridSpacing = 200;          // Test grid spacing
input int TestMaxOrders = 5;              // Test with fewer orders
input bool RunCalculationTests = true;    // Run calculation tests
input bool RunOrderTests = false;         // Run order placement tests (demo only!)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== Grid Trading EA Tester Started ===");
    
    if(RunCalculationTests)
    {
        TestCalculations();
    }
    
    if(RunOrderTests)
    {
        if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
        {
            TestOrderOperations();
        }
        else
        {
            Print("WARNING: Order tests can only be run on demo accounts!");
        }
    }
    
    Print("=== Grid Trading EA Tester Completed ===");
}

//+------------------------------------------------------------------+
//| Test calculation functions                                        |
//+------------------------------------------------------------------+
void TestCalculations()
{
    Print("--- Testing Calculation Functions ---");
    
    // Test 1: Point value calculation
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    Print("Symbol: ", _Symbol);
    Print("Point value: ", point);
    Print("Digits: ", digits);
    
    // Test 2: Grid price calculations
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    Print("Current ASK price: ", NormalizeDouble(currentPrice, digits));
    
    Print("Grid levels:");
    for(int i = 1; i <= TestMaxOrders; i++)
    {
        double gridPrice = currentPrice - (TestGridSpacing * point * i);
        Print("Level ", i, ": ", NormalizeDouble(gridPrice, digits));
    }
    
    // Test 3: Average price calculation
    TestAveragePriceCalculation();
    
    // Test 4: Profit target calculation
    TestProfitTargetCalculation();
    
    // Test 5: Margin calculation
    TestMarginCalculation();
}

//+------------------------------------------------------------------+
//| Test average price calculation                                   |
//+------------------------------------------------------------------+
void TestAveragePriceCalculation()
{
    Print("--- Testing Average Price Calculation ---");
    
    // Simulate positions at different prices
    double prices[] = {1.1000, 1.0950, 1.0900, 1.0850};
    double volumes[] = {0.01, 0.01, 0.01, 0.01};
    
    double totalVolume = 0;
    double averagePrice = 0;
    
    for(int i = 0; i < ArraySize(prices); i++)
    {
        totalVolume += volumes[i];
        averagePrice += prices[i] * volumes[i];
    }
    
    if(totalVolume > 0)
    {
        averagePrice = averagePrice / totalVolume;
    }
    
    Print("Test positions:");
    for(int i = 0; i < ArraySize(prices); i++)
    {
        Print("Position ", i+1, ": Price=", prices[i], ", Volume=", volumes[i]);
    }
    
    Print("Total Volume: ", totalVolume);
    Print("Average Price: ", NormalizeDouble(averagePrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
}

//+------------------------------------------------------------------+
//| Test profit target calculation                                   |
//+------------------------------------------------------------------+
void TestProfitTargetCalculation()
{
    Print("--- Testing Profit Target Calculation ---");
    
    double averagePrice = 1.0925; // Example average price
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double targetPrice = averagePrice + (TestProfitPoints * point);
    
    Print("Average Entry Price: ", averagePrice);
    Print("Profit Points: ", TestProfitPoints);
    Print("Point Value: ", point);
    Print("Target Price: ", NormalizeDouble(targetPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
    Print("Profit in points: ", (targetPrice - averagePrice) / point);
}

//+------------------------------------------------------------------+
//| Test margin calculation                                          |
//+------------------------------------------------------------------+
void TestMarginCalculation()
{
    Print("--- Testing Margin Calculation ---");
    
    double marginPerLot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    double totalMarginRequired = (TestMaxOrders + 1) * TestLotSize * marginPerLot;
    double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    
    Print("Margin per lot: ", marginPerLot);
    Print("Test lot size: ", TestLotSize);
    Print("Total orders: ", TestMaxOrders + 1, " (including market order)");
    Print("Total margin required: ", totalMarginRequired);
    Print("Available free margin: ", freeMargin);
    Print("Margin sufficient: ", (freeMargin >= totalMarginRequired) ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Test order operations (demo only)                               |
//+------------------------------------------------------------------+
void TestOrderOperations()
{
    Print("--- Testing Order Operations (DEMO ONLY) ---");
    
    int testMagic = 999999; // Special magic number for testing
    
    // Test 1: Place a small buy limit order
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double testPrice = currentPrice - (500 * point); // Far below current price
    
    Print("Attempting to place test buy limit order...");
    Print("Test price: ", NormalizeDouble(testPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
    
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = TestLotSize;
    request.type = ORDER_TYPE_BUY_LIMIT;
    request.price = NormalizeDouble(testPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    request.magic = testMagic;
    request.comment = "GridEA_Test";
    
    bool success = OrderSend(request, result);
    
    if(success)
    {
        Print("Test order placed successfully. Ticket: ", result.order);
        
        // Wait a moment, then remove the test order
        Sleep(2000);
        
        Print("Removing test order...");
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_REMOVE;
        request.order = result.order;
        
        bool removeSuccess = OrderSend(request, result);
        if(removeSuccess)
        {
            Print("Test order removed successfully.");
        }
        else
        {
            Print("Failed to remove test order. Error: ", GetLastError());
        }
    }
    else
    {
        Print("Failed to place test order. Error: ", GetLastError());
        Print("This might be due to trading restrictions or insufficient margin.");
    }
    
    // Test 2: Check spread and trading conditions
    TestTradingConditions();
}

//+------------------------------------------------------------------+
//| Test trading conditions                                          |
//+------------------------------------------------------------------+
void TestTradingConditions()
{
    Print("--- Testing Trading Conditions ---");
    
    // Check spread
    int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    Print("Current spread: ", spread, " points");
    
    // Check minimum lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    Print("Min lot size: ", minLot);
    Print("Max lot size: ", maxLot);
    Print("Lot step: ", lotStep);
    
    // Check trading session
    bool tradeAllowed = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL;
    Print("Trading allowed: ", tradeAllowed ? "YES" : "NO");
    
    // Check market status
    datetime serverTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    
    Print("Server time: ", TimeToString(serverTime));
    Print("Day of week: ", dt.day_of_week, " (1=Sunday, 7=Saturday)");
    
    // Check account info
    Print("Account balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Account equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
    Print("Free margin: ", AccountInfoDouble(ACCOUNT_FREEMARGIN));
    Print("Margin level: ", AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), "%");
}

//+------------------------------------------------------------------+
//| Test performance with multiple scenarios                        |
//+------------------------------------------------------------------+
void TestPerformanceScenarios()
{
    Print("--- Testing Performance Scenarios ---");
    
    // Scenario 1: Market moving down (grid orders triggered)
    Print("Scenario 1: Market declining, grid orders triggered");
    double entryPrices[] = {1.1000, 1.0950, 1.0900, 1.0850, 1.0800};
    double volumes[] = {0.01, 0.01, 0.01, 0.01, 0.01};
    
    SimulateGridPerformance(entryPrices, volumes, 1.1200); // Target above average
    
    // Scenario 2: Market moving up quickly (profit target hit)
    Print("Scenario 2: Market recovering, profit target achieved");
    SimulateGridPerformance(entryPrices, volumes, 1.0925 + (TestProfitPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT)));
}

//+------------------------------------------------------------------+
//| Simulate grid performance                                        |
//+------------------------------------------------------------------+
void SimulateGridPerformance(double &prices[], double &volumes[], double exitPrice)
{
    double totalVolume = 0;
    double averagePrice = 0;
    double totalCost = 0;
    
    // Calculate average entry price
    for(int i = 0; i < ArraySize(prices); i++)
    {
        totalVolume += volumes[i];
        totalCost += prices[i] * volumes[i];
    }
    
    averagePrice = totalCost / totalVolume;
    
    // Calculate profit/loss
    double totalValue = exitPrice * totalVolume;
    double profit = totalValue - totalCost;
    double profitPoints = (exitPrice - averagePrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    Print("Total positions: ", ArraySize(prices));
    Print("Total volume: ", totalVolume);
    Print("Average entry price: ", NormalizeDouble(averagePrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
    Print("Exit price: ", NormalizeDouble(exitPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
    Print("Profit in points: ", NormalizeDouble(profitPoints, 1));
    Print("Profit in currency: ", NormalizeDouble(profit, 2));
    Print("---");
}
