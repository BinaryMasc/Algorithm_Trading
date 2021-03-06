//+------------------------------------------------------------------+
//|                                                   MAHA US500.mq5 |
//|                                                        BinaryDog |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "BinaryDog"
#property version   "1.00"

// Estrategia técnica basada en HA y MA para operar pares de Forex

input int MagicNumber = 111110;
input int Slippage = 3;
input int MA_PERIOD_LONG = 100;
input int MA_PERIOD_SHORT = 100;
input ENUM_MA_METHOD MA_MODE_LONG = 0;
input ENUM_MA_METHOD MA_MODE_SHORT = 0;
input double Lots = 0.1;

input bool UseHeikenAshi = true;
input bool CalculateInNewBar = true;
input bool LotsAuto = true;
input bool ConditionsTime = true;   // Time conditions

input double FactorLoss = 0.5; // Factor Loss:  Loss/Profit. 

double ExpectationProfit;
double ExpectationLoss;

double lotss;

datetime Old_Time;
datetime New_Time;

double currentMax;
double currentMin;

// Test Values
double ExpectPIPSWin = 0.0040;   
double ExpectPIPSLose = ExpectPIPSWin/2;
// ---

double FactorRange = 0.55;
int MaxMinPeriod = 60;

#define HAHIGH      0
#define HALOW       1
#define HAOPEN      2
#define HACLOSE     3

#define Expect 0.25



#include <Trade\Trade.mqh>


color color1 = Red;
color color2 = Blue;
color color3 = Red;
color color4 = Blue;

CTrade trade;


int MainMA_LONG_Handle;
int MainMA_SHORT_Handle;
//--
int HeikenAshi_Handle = 0;

double MaxChart = 0;
double LowChart = 0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   MainMA_LONG_Handle  = iMA(Symbol(),PERIOD_CURRENT, MA_PERIOD_LONG,0,MA_MODE_LONG,PRICE_CLOSE);
   MainMA_SHORT_Handle = iMA(Symbol(),PERIOD_CURRENT, MA_PERIOD_SHORT,0,MA_MODE_SHORT,PRICE_CLOSE);
   
   if(UseHeikenAshi) HeikenAshi_Handle = iCustom(Symbol(),PERIOD_CURRENT, "Examples\\Heiken_Ashi.ex5",0);
   
   if(MainMA_LONG_Handle < 0 || MainMA_SHORT_Handle < 0 || HeikenAshi_Handle < 0) 
      return(INIT_FAILED);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
   //---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   bool newbar = isNewBar();
   
   if(PositionsTotal() > 0 && newbar) verificarOperacionesAbiertas(Symbol());
   
   
   if(!newbar && CalculateInNewBar) return;
   
   if(LotsAuto) lotss = AccountInfoDouble(ACCOUNT_BALANCE) / 10000;
   else lotss = Lots; 
   
   lotss = NormalizeDouble(lotss,2);
   
   //---



   bool ErrorIndicator = false;
   
   // Refresh Indicators
   
   //--- Buffers ---
   double _MALong[],
          _MAShort[],
          _HAHigh[],
          _HALow[],
          _HAOpen[],
          _HAClose[];
   //---


   ArraySetAsSeries(_MALong, true);
   ArraySetAsSeries(_MAShort, true);
   
   ArraySetAsSeries(_HAHigh, true);
   ArraySetAsSeries(_HALow, true);
   ArraySetAsSeries(_HAOpen, true);
   ArraySetAsSeries(_HAClose, true);
   
   if (CopyBuffer(MainMA_LONG_Handle,0,0,3,_MALong) < 0)  {Print("CopyBuffer MainMA_LONG_Handle Error = ",GetLastError());      ErrorIndicator = true;}
   if (CopyBuffer(MainMA_SHORT_Handle,0,0,3,_MAShort) < 0) {Print("CopyBuffer MainMA_SHORT_Handle error = ",GetLastError());      ErrorIndicator = true;}
   
   if(UseHeikenAshi){
      if (CopyBuffer(HeikenAshi_Handle,0,0,3,_HAOpen) < 0)  {Print("CopyBufferHA_Open error (1) = ",GetLastError()); ErrorIndicator = true;}
      if (CopyBuffer(HeikenAshi_Handle,1,0,200,_HAHigh) < 0){Print("CopyBufferHA_High error (1)= ",GetLastError()); ErrorIndicator = true;}
      if (CopyBuffer(HeikenAshi_Handle,2,0,200,_HALow) < 0) {Print("CopyBufferHA_Low error (1)= ",GetLastError()); ErrorIndicator = true;}
      if (CopyBuffer(HeikenAshi_Handle,3,0,200,_HAClose) < 0) {Print("CopyBufferHA_Close error (1)= ",GetLastError()); ErrorIndicator = true;}   
   }
   else{
      if (CopyOpen (Symbol(),PERIOD_CURRENT, 1,3  , _HAOpen) < 0){Print("CopyBufferHA_Open error = (2)",GetLastError()); ErrorIndicator = true;}
      if (CopyHigh (Symbol(),PERIOD_CURRENT, 1,200, _HAHigh) < 0){Print("CopyBufferHA_High error (2)= ",GetLastError()); ErrorIndicator = true;}
      if (CopyLow  (Symbol(),PERIOD_CURRENT, 1,200, _HALow)  < 0){Print("CopyBufferHA_Low error (2)= ",GetLastError()); ErrorIndicator = true;}
      if (CopyClose(Symbol(),PERIOD_CURRENT, 1,200, _HAClose)  < 0){Print("CopyBufferHA_Close error (2)= ",GetLastError()); ErrorIndicator = true;}
   }   
   
   // MA[] { 0,   1,    2}
   //        ^ Current bar -> Position 0
   //             ^ Previous bar -> Position 1
   
   //Print("HAOpen Previous: ", _HAOpen[1]);
   //Print("HAHigh Previous: ", _HAHigh[1]);
   //Print("HALow Previous: ", _HALow[1]);
   //Print("HAClose Previous: ", _HAClose[1]);
   
   if(ErrorIndicator){ Print("Error Indicator: ", GetLastError()); return;}
   
   
   currentMax = calcMax(_HAClose);
   currentMin = calcMin(_HAClose);
   double Price = _HAClose[0];
   double range = currentMax - currentMin;
   
   ExpectPIPSWin = range * FactorRange;
   ExpectPIPSLose = ExpectPIPSWin*FactorLoss;
   
   //---
   long ord = 0;
   
   if(PositionsTotal()==0 && 
      VerificarCondicionesCompra(_MALong, _HAHigh, _HALow, _HAOpen, _HAClose) &&
      VerificarCondicionesHorarias())
   {
      //ord = enviarOrden(Symbol(), 0, NormalizeDouble(ExpectationLoss,_Digits)*1000000, NormalizeDouble(ExpectationProfit,_Digits)*1000000);
      ord = enviarOrden(Symbol(), 0, 0, 0);
   }
   
   else if(PositionsTotal()==0 && 
           VerificarCondicionesVenta(_MAShort, _HAHigh, _HALow, _HAOpen, _HAClose) &&
           VerificarCondicionesHorarias())
   {
      
      //ord = enviarOrden(Symbol(), 1, NormalizeDouble(ExpectationLoss,_Digits)*1000000, NormalizeDouble(ExpectationProfit,_Digits)*1000000);
      ord = enviarOrden(Symbol(), 1, 0, 0);
   }
   
   if(ord < 0) Print("Error in OrderSend: ", GetLastError());
   
//---   
  }
//+------------------------------------------------------------------+
bool VerificarCondicionesCompra(double &MABuffer[],
                                double &HAHighBuffer[],
                                double &HALowBuffer[],
                                double &HAOpen[],
                                double &HAClose[])
{
   if(MABuffer[2] < MABuffer[1] &&           // |        /
                                             // |    _  /
      HAOpen[1] < HAClose[1] &&              // |   / \/
                                             // |  /
      HALowBuffer[1] < MABuffer[1] &&        // |____________

      HAClose[1] > MABuffer[1])
         return true;
         
   else return false;                           // MA[] { 0,   1,    2}
                                                //        ^ Current bar -> Position 0
                                                //             ^ Previous bar -> Position 1
}
//---
bool VerificarCondicionesVenta(double &MABuffer[],
                               double &HAHighBuffer[],
                               double &HALowBuffer[],
                               double &HAOpen[],
                               double &HAClose[])
{
   if(MABuffer[2] > MABuffer[1] &&
   
      HAOpen[1] > HAClose[1] &&
      
      HAHighBuffer[1] > MABuffer[1] &&
      
      HAClose[1] < MABuffer[1])
         return true;
         
   else return false;      
}
//---
bool VerificarCondicionesHorarias()
{
   if(!ConditionsTime) return true;
   datetime    tm=TimeCurrent();
   MqlDateTime stm;
   TimeToStruct(tm,stm);
   
   if(stm.day_of_week != 1 && 
      stm.day_of_week != 5 && 
      stm.hour != 2 &&
      stm.hour != 1) 
         return true;
         
         
   else return false;
}

//+------------------------------------------------------------------+
bool enviarOrden(string symbol, int OrderTypee, const double SL, const double TP)   
{
      
      
      bool op = false;
      
      double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
      double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
      // OrderSend : BUY = 0, SELL = 1
      if(OrderTypee == 0)
      {
         double SLLevel = Bid-(SL*_Point);
         double TPLevel = Bid+(TP*_Point);
         
         if(SL == 0 && TP == 0)
         {
            SLLevel = 0;
            TPLevel = 0;
         }
         
         op = trade.Buy(Lots,
                        NULL,
                        Ask,
                        SLLevel, //   5 DIGITS
                        TPLevel,
                        NULL);
           
      }   
      else if(OrderTypee == 1)
      {
         double SLLevel = Ask+(SL*_Point);
         double TPLevel = Ask-(TP*_Point);
         
         
         if(SL == 0 && TP == 0)
         {
            SLLevel = 0;
            TPLevel = 0;
         }
         
         op = trade.Sell(Lots,
                        NULL,
                        Bid,
                        SLLevel,
                        TPLevel,
                        NULL);
                   
         //double stoploss = NormalizeDouble(SYMBOL_ASK+Expectation*Point(),Digits());
         //double takeprofit = NormalizeDouble(SYMBOL_ASK-Expectation*Point(),Digits());
         
         //op = OrderSend(Symbol(), OrderTypee, Lots, SYMBOL_BID, Slippage, stoploss, takeprofit, NULL, MagicNumber, 0, Red);
      }   
      
      return op;     
}

//+------------------------------------------------------------------+
double VolatilidadMax(int cobertura, double &HighBuffer[], double &LowBuffer[])
{
   
   double temp = MaximoEnGrafico(cobertura,HighBuffer) - MinimoEnGrafico(cobertura,LowBuffer);
   return temp;
}

double MaximoEnGrafico(int cobertura, double &High[]){
   
   int i = ArrayMaximum(High, cobertura, 1);
   
   return High[i];
      
}

double MinimoEnGrafico(int cobertura, double &Low[]){
   int i = ArrayMinimum(Low, cobertura, 1);
   
   return Low[i]; 
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
double calcMax(double &ClosesBuffer[])
{
   double Max = 0;
   for(int i = 0; i < MaxMinPeriod; i++) if(ClosesBuffer[i] > Max) Max = ClosesBuffer[i];
   
   return Max;
}

double calcMin(double &ClosesBuffer[])
{
   double Min = 9999999;
   for(int i = 0; i < MaxMinPeriod; i++) if(ClosesBuffer[i] < Min) Min = ClosesBuffer[i];
   
   return Min;
}
//+------------------------------------------------------------------+
bool isNewBar()
{
   New_Time = iTime(Symbol(),PERIOD_CURRENT, 0);
   
   if(New_Time != Old_Time) 
   {
      Old_Time = New_Time;
      return true; 
   }
   else return false;
}
//+------------------------------------------------------------------+
void verificarOperacionesAbiertas(string symbol)
{
   bool sucess;
      sucess = PositionSelect(symbol);
      
      double Ask = NormalizeDouble(SymbolInfoDouble(symbol,SYMBOL_ASK),_Digits);
      double Bid = NormalizeDouble(SymbolInfoDouble(symbol,SYMBOL_BID),_Digits);
      
      
      
      if(sucess)
      {
         bool isPositive= true;
         double OpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         long type = PositionGetInteger(POSITION_TYPE);
         
         double difAsk = NormalizeDouble(MathAbs(OpenPrice - Ask),_Digits);
         double difBid = NormalizeDouble(MathAbs(OpenPrice - Bid),_Digits);
         
         if(type == POSITION_TYPE_BUY  && (OpenPrice < Ask)) isPositive = true;
         if(type == POSITION_TYPE_BUY  && (OpenPrice > Ask)) isPositive = false;
         if(type == POSITION_TYPE_SELL && (OpenPrice < Bid)) isPositive = false;
         if(type == POSITION_TYPE_SELL && (OpenPrice > Bid)) isPositive = true;
         
         //Print("DifBid : ",difBid);
         if(type == POSITION_TYPE_BUY)
         {
            if((Ask >= currentMax || difAsk >= ExpectPIPSWin) && isPositive) trade.PositionClose(symbol,Slippage);
            else if((Ask >= currentMax || difAsk >= ExpectPIPSLose) && !isPositive) trade.PositionClose(symbol,Slippage);
         }
         else if(type == POSITION_TYPE_SELL)
         {
            if((Bid <= currentMin || difBid >= ExpectPIPSWin) && isPositive) trade.PositionClose(symbol,Slippage);
            else if((Bid <= currentMin || difBid >= ExpectPIPSLose) && !isPositive) trade.PositionClose(symbol,Slippage);
         }
      }
}
//+------------------------------------------------------------------+