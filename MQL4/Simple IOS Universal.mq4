//+------------------------------------------------------------------+
//|                                         Simple IOS Universal.mq4 |
//|                                                        BinaryDog |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BinaryDog"
#property link      ""
#property version   "1.00"
#property strict

//-------------------------------------------------------------------

extern int MagicNumber = 12345670;
extern int Slippage = 3;
extern float Expect = 0.4;
float Lots = 0.1;
extern int MAPeriod = 55;
extern int MAMode = 3;

//int MAModeEURUSD = 3;
//int MAPeriodEURUSD = 102;
//float expectEURUSD = 0.2;

//int MAModeAUDCHF = 0;
//int MAPeriodAUDCHF = 55;
//float expectAUDCHF = 0.4;

//int MAModeGold = 1;
//int MAPeriodGold = 27;
//float expectGold = 0.4;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // Comprobar y enviar ordenes en apertura de mercado
   if(Hour() == 8 && Minute() == 0)
   {
      
      Lots = 0.01;//AccountBalance()/10000;
      int ord = enviarOrden(Symbol(),MAMode,MAPeriod);
      //printInfo(ord, "EURUSD");
      
      //ord = enviarOrden("EURUSD",MAMode,MAPeriod);
      //printInfo(ord, "EURUSD");
        
   }
   
   // Verificar y cerrar operaciones abiertas
   if(Minute() == 0 && hayTradesAbiertos())
   {
      CerrarOperaciones(Symbol(), Expect);
   }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
   
   
}
//+------------------------------------------------------------------+

int TotalOrdersCount(string symbol)
{
   int result=0;
   for(int i=0; i<OrdersTotal(); i++)
     {
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderMagicNumber() == MagicNumber && OrderSymbol ()== symbol)
         result++;
   
     }
   return (result);
}
//+------------------------------------------------------------------+
bool hayTradesAbiertos()
   {

   for(int i=0; i<OrdersTotal(); i++)
     {
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderMagicNumber()==MagicNumber)
         return true;

     }
     
     return false;
   }
//+------------------------------------------------------------------+

// Funcion devuelve 0 si no abre operacion debido a que hay operaciones abiertas con ese par
// o si no se cumplen las condiciones para operarlo, -1 si hay error y 1 si abrió operación.

int enviarOrden(string symbol, int Mode_MA, int Period_MA)
{
   
   if(TotalOrdersCount(symbol) > 0) return 0;
   
   int result = 0;
   
   ChartSetSymbolPeriod(0, symbol,PERIOD_H1);
   // Comprobar orden de compra
   if(Close[0] > iMA(NULL, 0, Period_MA,0, Mode_MA, PRICE_CLOSE, 0))
   {
      int op = OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,0,0,"",MagicNumber,0,Blue);
      
      if(op != -1) result = 1; 
      else result = -1;
      
      if(result == -1 || result == 1) return result;
   }
   
   // Comprobar orden de venta
   if(Close[0] < iMA(NULL, 0, Period_MA,0, Mode_MA, PRICE_CLOSE, 0))
   {
      int op = OrderSend(Symbol(),OP_SELL,Lots,Bid,Slippage,0,0,"",MagicNumber,0,Blue);
      
      if(op != -1) result = 1; 
      else result = -1;
      
      if(result == -1 || result == 1) return result;
      
   }
   
   return result;
   
}

//+------------------------------------------------------------------+
void CerrarOperaciones(string symbol,float expect)
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      
      if(OrderSymbol() != symbol) continue;
      
      
      int ExpectPips = (VolatilidadMax(100)*10000)*expect;
      
      if(OrderType()<=OP_SELL &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
      {
         if(OrderType()==OP_BUY)
         {
            // En caso de Posición positiva:
            if(Bid >= OrderOpenPrice()+(ExpectPips*0.0001))
               OrderClose(OrderTicket(),Lots,Bid,Slippage,Red);
               
               
            // En caso de Posición Negativa:
            else if(Bid <= OrderOpenPrice()-(ExpectPips*0.0001))
                  OrderClose(OrderTicket(),Lots,Bid,Slippage,Red);
         }
         else
         {
            // En caso de Posición positiva:
            if(Ask <= OrderOpenPrice()-(ExpectPips*0.0001))
                  OrderClose(OrderTicket(),Lots,Ask,Slippage,Red);
            
            // En caso de Posición Negativa:      
            else if(Ask >= OrderOpenPrice()+(ExpectPips*0.0001))
                  OrderClose(OrderTicket(),Lots,Ask,Slippage,Red);
         }
      }   
   }
}
//+------------------------------------------------------------------+


void printInfo(int info, string symbol)
{
   if(info == -1)
      Print("Error en el par " + symbol + ". " + GetLastError());
   
   else if(info == 1)
      Print("Orden enviada en el par " + symbol + " con éxito.");
      
   else Print("No se cumplieron condiciones de entrada en el par " + symbol + ".");

}

//+------------------------------------------------------------------+
double VolatilidadMax(int cobertura)
{
   
   double temp = MaximoEnGrafico(cobertura) - MinimoEnGrafico(cobertura);
   return temp;
}

double MaximoEnGrafico(int cobertura){
   
   int i = ArrayMaximum(High, cobertura, 1);
   
   return High[i];
      
}

double MinimoEnGrafico(int cobertura){
   int i = ArrayMinimum(Low, cobertura, 1);
   
   return Low[i]; 
}
//+------------------------------------------------------------------+