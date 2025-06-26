//+------------------------------------------------------------------+
//|                                            GridTradingConfig.mqh |
//|                                  Copyright 2025, Jaziel Trader    |
//|                                Configuration file for Grid EA     |
//+------------------------------------------------------------------+

#ifndef GRID_TRADING_CONFIG_H
#define GRID_TRADING_CONFIG_H

//--- Default Configuration Settings
//--- These can be overridden by input parameters

// Trading Parameters
#define DEFAULT_LOT_SIZE           0.1      // Default lot size
#define DEFAULT_PROFIT_POINTS      200      // Default profit target in points
#define DEFAULT_GRID_SPACING       200      // Default grid spacing in points
#define DEFAULT_MAX_GRID_ORDERS    20       // Default maximum grid orders
#define DEFAULT_MAGIC_NUMBER       123456   // Default magic number

// Risk Management
#define MAX_SPREAD_POINTS          50       // Maximum allowed spread in points
#define MIN_FREE_MARGIN_PERCENT    20       // Minimum free margin percentage
#define MAX_SLIPPAGE_POINTS        10       // Maximum slippage for market orders

// Trading Hours (in server time)
#define TRADING_START_HOUR         0        // Start trading hour (0-23)
#define TRADING_END_HOUR           23       // End trading hour (0-23)
#define ENABLE_TRADING_HOURS       false    // Enable/disable trading hours filter

// Symbol Settings
#define ALLOWED_SYMBOLS            ""       // Comma-separated list (empty = all symbols)
#define MIN_ACCOUNT_CURRENCY       1000     // Minimum account balance required

// Advanced Settings
#define ENABLE_NEWS_FILTER         false    // Enable news filter (requires external feed)
#define MAX_DAILY_TRADES           100      // Maximum trades per day
#define ENABLE_WEEKEND_TRADING     false    // Allow trading on weekends

// Logging and Monitoring
#define ENABLE_DETAILED_LOGGING    true     // Enable detailed logging
#define LOG_LEVEL                  2        // 0=Errors, 1=Warnings, 2=Info, 3=Debug

//--- Helper Functions

// Check if trading is allowed based on time
bool IsTradingTimeAllowed()
{
    if(!ENABLE_TRADING_HOURS) return true;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    return (dt.hour >= TRADING_START_HOUR && dt.hour <= TRADING_END_HOUR);
}

// Check if symbol is allowed
bool IsSymbolAllowed(string symbol)
{
    if(ALLOWED_SYMBOLS == "") return true;
    
    string symbols[];
    int count = StringSplit(ALLOWED_SYMBOLS, ',', symbols);
    
    for(int i = 0; i < count; i++)
    {
        if(symbols[i] == symbol)
            return true;
    }
    
    return false;
}

// Check margin requirements
bool IsMarginSufficient(double requiredMargin)
{
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    if(marginLevel > 0 && marginLevel < MIN_FREE_MARGIN_PERCENT)
        return false;
    
    return (freeMargin > requiredMargin);
}

// Check spread conditions
bool IsSpreadAcceptable(string symbol)
{
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    return (spread <= MAX_SPREAD_POINTS);
}

// Get adjusted lot size based on account balance
double GetAdjustedLotSize(double baseLotSize)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    // Simple risk-based adjustment (can be customized)
    double adjustedLot = baseLotSize;
    
    if(balance < 1000)
        adjustedLot = MathMin(adjustedLot, 0.01);
    else if(balance < 5000)
        adjustedLot = MathMin(adjustedLot, 0.1);
    
    return MathMax(minLot, MathMin(maxLot, adjustedLot));
}

// Log message with level filtering
void LogMessage(int level, string message)
{
    if(!ENABLE_DETAILED_LOGGING || level > LOG_LEVEL)
        return;
    
    string levelText;
    switch(level)
    {
        case 0: levelText = "[ERROR]"; break;
        case 1: levelText = "[WARN]"; break;
        case 2: levelText = "[INFO]"; break;
        case 3: levelText = "[DEBUG]"; break;
        default: levelText = "[UNKNOWN]"; break;
    }
    
    Print(levelText, " ", TimeToString(TimeCurrent()), " - ", message);
}

#endif // GRID_TRADING_CONFIG_H
