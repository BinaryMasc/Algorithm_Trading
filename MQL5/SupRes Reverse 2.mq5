//+------------------------------------------------------------------+
//|                                               SupRes Reverse.mq5 |
//|                                                        BinaryDog |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BinaryDog"
#property version   "1.00"

#define rangeBuffer 300

// Utiliza la estrategia técnica de soportes y resistencias a la inversa

#include <Trade\Trade.mqh>

CTrade trade;

input int MagicNumber = 100001;
input int Slippage = 20;
input double Lots = 0.1;
input bool CalculateInNewBar = true;
input bool LotsAuto = true;
input bool UseMAsVerification = false;

input double FactorLoss = 0.5; // Factor Loss:  Loss/Profit. 
double FactorRange = 0.55;
int MaxMinPeriod = 60;
int MAFastPeriod = 8;
ENUM_MA_METHOD MAFastMeth = MODE_SMA;
int MALowPeriod = 20;
ENUM_MA_METHOD MALowMeth = MODE_SMA;
int MAMainPeriod = 200;
ENUM_MA_METHOD MAMainMeth = MODE_SMA;


datetime Old_Time;
datetime New_Time;

int MAMainHandle;
int MAFastHandle;
int MALowHandle;

double currentMax;
double currentMin;

double ExpectPIPSWin = 0.0040;
double ExpectPIPSLose = ExpectPIPSWin/2;

double ExpectationProfit;
double ExpectationLoss;

double lotss;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   //MAFastHandle = iMA(Symbol(),PERIOD_CURRENT, MAFastPeriod,0,MAFastMeth,PRICE_CLOSE);
   //MALowHandle  = iMA(Symbol(),PERIOD_CURRENT, MALowPeriod, 0,MALowMeth,PRICE_CLOSE);
   MAMainHandle = iMA(Symbol(),PERIOD_CURRENT, MAMainPeriod,0,MAMainMeth,PRICE_CLOSE);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   // Verify new bar
   bool newbar = isNewBar();
   
   // Manage the positions
   if(PositionsTotal() > 0 && newbar) verificarOperacionesAbiertas(Symbol());
   
   
   if(!newbar && CalculateInNewBar) return;
   
   if(LotsAuto) lotss = AccountInfoDouble(ACCOUNT_BALANCE) / 10000;
   else lotss = Lots; 
   
   lotss = NormalizeDouble(lotss,2);
   
   
   bool ErrorIndicator = false;
   
   // Refresh Indicators
   
   //--- Buffers ---
   double _HighsBuffer[],
          _LowsBuffer[],
          _ClosesBuffer[],
          _MAMainBuffer[];
   
   ArraySetAsSeries(_ClosesBuffer, true);
   ArraySetAsSeries(_LowsBuffer, true);
   ArraySetAsSeries(_HighsBuffer, true);
   ArraySetAsSeries(_MAMainBuffer, true);
   
   
   // Set Buffers indicators
   if (CopyHigh(Symbol(),PERIOD_CURRENT, 1,rangeBuffer, _HighsBuffer) < 0){Print("CopyHigh Historical Data Error = ",GetLastError());ErrorIndicator = true;}
   //
   if (CopyLow(Symbol(), PERIOD_CURRENT, 1,rangeBuffer, _LowsBuffer) < 0) {Print("CopyLow Historical Data Error = ",GetLastError());ErrorIndicator = true;}
   //
   if (CopyClose(Symbol(),PERIOD_CURRENT,0,rangeBuffer, _ClosesBuffer) < 0){Print("CopyClose Historical Data Error = ",GetLastError());ErrorIndicator = true;}
   //
   //if (CopyBuffer(MAFastHandle,0,0,5,_MAFastBuffer) < 0)  {Print("CopyBuffer MAFast_Handle Error = ",GetLastError());ErrorIndicator = true;}
   //
   //if (CopyBuffer(MALowHandle,0,0,5, _MASlowBuffer) < 0)  {Print("CopyBuffer MALow_Handle Error = ", GetLastError());ErrorIndicator = true;}
   //
   if (CopyBuffer(MAMainHandle,0,0,5,_MAMainBuffer) < 0)  {Print("CopyBuffer MAMain_Handle Error = ", GetLastError());ErrorIndicator = true;}
   
   if(ErrorIndicator){ Print("Error Indicator: ", GetLastError()); return;}
   
   currentMax = calcMax(_ClosesBuffer);
   currentMin = calcMin(_ClosesBuffer);
   double Price = _ClosesBuffer[0];
   double range = currentMax - currentMin;
   
   ExpectPIPSWin = range * FactorRange;
   ExpectPIPSLose = ExpectPIPSWin*FactorLoss;
   
   long ord = 0;
   
   // Debug
   //Print(_MAFastBuffer[0],",",_MAFastBuffer[1],",",_MAFastBuffer[2],",",_MAFastBuffer[3],",",_MAFastBuffer[4],",");
   //Print(_MASlowBuffer[0],",",_MASlowBuffer[1],",",_MASlowBuffer[2],",",_MASlowBuffer[3],",",_MASlowBuffer[4],",");
   
   if(VerificarCondicionesCompra(currentMin, Price,_MAMainBuffer)
      && PositionsTotal() == 0)
      {
         ExpectationProfit = 0.00040;  // TODO: TEMPORAL CODE
         ExpectationLoss = ExpectationProfit;
         
         ord = enviarOrden(Symbol(), 0, NormalizeDouble(ExpectationLoss,_Digits)*1000000, NormalizeDouble(ExpectationProfit,_Digits)*1000000);
         //ord = enviarOrden(Symbol(), 0, 0,0);
      }
      
   else if(VerificarCondicionesVenta(currentMax, Price,_MAMainBuffer)
      && PositionsTotal() == 0)  
      {
         //ExpectationProfit = (Expect*(VolatilidadMax(RangeExpect, _HighsBuffer, _LowsBuffer)))/1;
         //Print("(!) Diferencia DE PIPS max - min = ", currentMax - currentMin);
         ExpectationProfit = 0.00040;  // TODO: TEMPORAL CODE
         ExpectationLoss = ExpectationProfit;
         
         ord = enviarOrden(Symbol(), 1, NormalizeDouble(ExpectationLoss,_Digits)*1000000, NormalizeDouble(ExpectationProfit,_Digits)*1000000);
      }
      
   //---
      
   if(ord < 0) Print("Error in OrderSend: ", GetLastError());   
   
   //

   Comment("MA[0]: ", _MAMainBuffer[0],"\nMA[1]: ", _MAMainBuffer[1]);
   
   
   
  }
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
bool VerificarCondicionesCompra(double Min, double Price, double &MAMainBuffer[])
{
   /*
   if((MAFastBuffer[0] < MAFastBuffer[1] && MAFastBuffer[1] < MAFastBuffer[2] && MAFastBuffer[2] < MAFastBuffer[3] && MAFastBuffer[3] < MAFastBuffer[4])
      && (MALowBuffer[0] < MALowBuffer[1] && MALowBuffer[1] < MALowBuffer[2] && MALowBuffer[2] < MALowBuffer[3] && MALowBuffer[3] < MALowBuffer[4])
      && (MAFastBuffer[0] > Price && MALowBuffer[0] > MAFastBuffer[0]) && UseMAsVerification) return false;*/
      
   if(Price <= Min && MAMainBuffer[0] < Price && MAMainBuffer[1] < MAMainBuffer[0]) return true;
   else return false;
}

bool VerificarCondicionesVenta(double Max, double Price, double &MAMainBuffer[])
{
   /*
   if((MAFastBuffer[0] > MAFastBuffer[1] && MAFastBuffer[1] > MAFastBuffer[2] && MAFastBuffer[2] > MAFastBuffer[3] && MAFastBuffer[3] > MAFastBuffer[4])
      && (MALowBuffer[0] > MALowBuffer[1] && MALowBuffer[1] > MALowBuffer[2] && MALowBuffer[2] > MALowBuffer[3] && MALowBuffer[3] > MALowBuffer[4])
      && (MAFastBuffer[0] < Price && MALowBuffer[0] < MAFastBuffer[0]) && UseMAsVerification) return false;*/
      
   if(Price >= Max && MAMainBuffer[0] > Price && MAMainBuffer[1] > MAMainBuffer[0]) return true;
   else return false;
}
//+------------------------------------------------------------------+
double VolatilidadMax(int cobertura, double &HighBuffer[], double &LowBuffer[])
{
   
   double temp = MaximoEnGrafico(cobertura,HighBuffer) - MinimoEnGrafico(cobertura,LowBuffer);
   return temp;
}
//---
double MaximoEnGrafico(int cobertura, double &High[]){
   
   //int i = ArrayMaximum(High, 1, cobertura);
   int i = ArrayMaximum(High, rangeBuffer-1-cobertura, cobertura);
   
   return High[i];
      
}
//---
double MinimoEnGrafico(int cobertura, double &Low[]){

   int i = ArrayMinimum(Low, rangeBuffer-1-cobertura, cobertura);
   
   return Low[i]; 
}
//+------------------------------------------------------------------+
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
         
         op = trade.Buy(lotss,
                        NULL,
                        Ask,
                        //SLLevel, //   5 DIGITS
                        //TPLevel,
                        0,0,
                        NULL);
           
      }   
      else if(OrderTypee == 1)
      {
         double SLLevel = Ask+(SL*_Point);
         double TPLevel = Ask-(TP*_Point);
      
         op = trade.Sell(lotss,
                        NULL,
                        Bid,
                        //SLLevel,
                        //TPLevel,
                        0,0,
                        NULL);
                   
         //double stoploss = NormalizeDouble(SYMBOL_ASK+Expectation*Point(),Digits());
         //double takeprofit = NormalizeDouble(SYMBOL_ASK-Expectation*Point(),Digits());
         
         //op = OrderSend(Symbol(), OrderTypee, Lots, SYMBOL_BID, Slippage, stoploss, takeprofit, NULL, MagicNumber, 0, Red);
      }   
      
      return op;     
}