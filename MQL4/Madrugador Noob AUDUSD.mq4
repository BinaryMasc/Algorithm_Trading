//+------------------------------------------------------------------+
//|                                       Madrugador Noob AUDUSD.mq4 |
//|                                                        BinaryDog |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BinaryDog"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

extern int MagicNumber=12345;
extern int TrailingStop=0;        // TrailingStop = 0 desactivado. TrailingStop != 0 activado
extern int Slippage=3;
extern double Lots=0.10;

double PipsProfitExpectation=40;
double PipsLoseExpectation=40;

extern int MAPeriodoTendencia=100;
extern int MAModoTendencia=3;

int MAPeriod = 69;
int ModeMA = MODE_LWMA;
float Parametro = 0.6;    //Porcentaje variacion de grafu¡ico para TP y SL

int ModoDeLotes = 1;       // 1 o <1: Lotaje fijo. // 2: Lotaje variable según capital.  // 3: Lotaje según movimientos del mercado (Alto riesgo)

bool statsFlag;

//+------------------------------------------------------------------+
//    expert start function
//+------------------------------------------------------------------+
int start()
  {
  
  //if(Hour() == 23 && Minute() == 0) statsFlag = false;
  //RegistrarEstadisticas(statsFlag);
  
   double MyPoint=Point;
   
   
   if(Digits==3 || Digits==5)
      MyPoint=Point*10;

   
   if(Hour() == 7 && Minute() == 0 && ModoDeLotes == 2) {
      Lots = AccountBalance()/10000;
      
   }
   
   
   if(TotalOrdersCount()==0)
     {
      
      int result=0;
      if(ModoDeLotes >= 3) Lots=(PipsProfitExpectation*(AccountBalance()/10000))/40;
      
      
      // Condición de compra
      if((Hour() == 8) && 
      Minute() == 0 &&
      (iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,0) < Close[0]) && 
      HayTendencia() == 1) 
        {
         
         result=OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,0,0,"",MagicNumber,0,Blue);
         return(0);
        }
        
      // Condición de venta
      if((Hour() == 8) && 
      Minute() == 0 &&
      (iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,0) > Close[0]) && 
      HayTendencia() == -1) 
        {
         
         result=OrderSend(Symbol(),OP_SELL,Lots,Bid,Slippage,0,0,"",MagicNumber,0,Red);
         return(0);
        }
     }

   // Ver si hay que cerrar una operación después de pasada una hora
   
   if(hayTradesAbiertos() && Minute() == 0)
   {
     for(int i=0; i<OrdersTotal(); i++)
      {
      
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      
      PipsLoseExpectation = (VolatilidadMax(100)*10000)*Parametro;
      PipsProfitExpectation = PipsLoseExpectation;
            
      if(OrderType()<=OP_SELL &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
        {
        
         // Evaluar condiciones de cierre
         if(OrderType()==OP_BUY)
           {
               // En caso de Posición positiva:
               if(Bid >= OrderOpenPrice()+(PipsProfitExpectation*0.0001))
               {
                  
                  if(TrailingStop != 0)
                  {
                     
                  }
                  else
                  {
                     OrderClose(OrderTicket(),Lots,Bid,Slippage,Red);
                  }
               }
                  
                  
               // En caso de Posición Negativa:
               else if((Bid <= OrderOpenPrice()-(PipsLoseExpectation*0.0001)) || 
                  (Close[1] < iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,1) && 
                  (Close[2] < iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,2)))) 
                     OrderClose(OrderTicket(),Lots,Bid,Slippage,Red);
           }
         else
           {
               if(Ask <= OrderOpenPrice()-(PipsProfitExpectation*0.0001))
                  OrderClose(OrderTicket(),Lots,Ask,Slippage,Red);
               
               else if((Ask >= OrderOpenPrice()+(PipsLoseExpectation*0.0001) || 
                  (Close[1] > iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,1) && 
                  (Close[2] > iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,2)))) ) 
                     OrderClose(OrderTicket(),Lots,Ask,Slippage,Red);
           }
        }
     }
   
   }
   
   return(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hayTradesAbiertos(){

   for(int i=0; i<OrdersTotal(); i++)
     {
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderMagicNumber()==MagicNumber)
         return true;

     }
     
     return false;
}

int TotalOrdersCount()
  {
   int result=0;
   for(int i=0; i<OrdersTotal(); i++)
     {
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderMagicNumber()==MagicNumber)
         result++;

     }
   return (result);
  }

// Evalúa los últimos 2 valores de la EMA de 55 periodos.
// Devuelve 0 si no hay tendencia. 1 si la tendencia es alcista y -1 si es bajista
int HayTendencia(){
   if(iMA(NULL,0,MAPeriodoTendencia,0,MAModoTendencia,PRICE_CLOSE,2) < iMA(NULL,0,MAPeriodoTendencia,0,MAModoTendencia,PRICE_CLOSE,1) && Close[0]> iMA(NULL,0,MAPeriodoTendencia,0,MAModoTendencia,PRICE_CLOSE,0))
      return 1;
   else if(iMA(NULL,0,MAPeriodoTendencia,0,MAModoTendencia,PRICE_CLOSE,2) > iMA(NULL,0,MAPeriodoTendencia,0,MAModoTendencia,PRICE_CLOSE,1) && Close[0]< iMA(NULL,0,MAPeriodoTendencia,0,MAModoTendencia,PRICE_CLOSE,0))
      return -1;
   
   else return 0;
}

double MaximoEnGrafico(int cobertura){
   
   int i = ArrayMaximum(High, cobertura, 1);
   
   return High[i];
      
}

double MinimoEnGrafico(int cobertura){
   int i = ArrayMinimum(Low, cobertura, 1);
   
   return Low[i]; 
}

double VolatilidadMax(int cobertura)
{
   
   double temp = MaximoEnGrafico(cobertura) - MinimoEnGrafico(cobertura);
   return temp;
}

double DiferenciaAbsPips(int min, int max)
{
   double temp = max-min;
   return temp;
}

bool VerificarDistanciaPriceMA()
{
   double difPIPS = iMA(NULL,0,MAPeriod,0,ModeMA,PRICE_CLOSE,0) - Close[0];
   difPIPS = MathAbs(difPIPS*10000);
   
   double difPercent = (difPIPS/(VolatilidadMax(100)*10000))*100;
   if(difPercent < 35) return true;
   else return false;
}

//+------------------------------------------------------------------+

// Estadísticas más detalladas de semanas y meses Backtest
void RegistrarEstadisticas(bool BanderaEstadisticas)
{
   if(Hour() == 1 && Minute() == 0 )//&& BanderaEstadisticas == false)
   {
      BanderaEstadisticas = true;
      if(FileIsExist("TempCapIniM") && FileIsExist("TempCrecMen") && FileIsExist("TempCapIniW") && FileIsExist("TempCrecSem"))
      {
         string temp ;
         double cap_anterior;
         
         if(FileSize(FileSize(FileOpen("TempCapIniM",FILE_REWRITE))) <= 2)
         {
            double balanceActual = AccountBalance();
            EscribirArchivo("TempCapIniM", DoubleToStr(balanceActual));
            EscribirArchivo("TempCapIniW", DoubleToStr(balanceActual));
            EscribirArchivo("TempCrecMen", "0");
            EscribirArchivo("TempCrecSem", "0");
         }
         
         if(DayOfWeek() == 0)
         {
            temp = "";
            
            temp = LeerArchivo("TempCapIniW");
            
            cap_anterior = StrToDouble(temp);
            
            double CrecimientoSemanal = (cap_anterior/AccountBalance())*100;
            
            printf("-------------------------------------");
            printf("Crecimiento semanal: " + CrecimientoSemanal);
            printf("-------------------------------------");         
            EscribirArchivo("TempCapIniW", AccountBalance());
            
            string dataSemanas = LeerArchivo("TempCrecSem");
            
            dataSemanas += ("\n" + CrecimientoSemanal);
            
            EscribirArchivo("TempCrecSem", dataSemanas);
            
         }
         
         if(Day() == 1)
         {
            temp = "";
            
            temp = LeerArchivo("TempCapIniM");
            
            cap_anterior = StrToDouble(temp);
            
            double CrecimientoMensual = (cap_anterior/AccountBalance())*100;
            
            printf("-------------------------------------");
            printf("Crecimiento mensual: " + CrecimientoMensual);
            printf("-------------------------------------");      
            
            EscribirArchivo("TempCapIniM", AccountBalance());
            
            string dataMeses = LeerArchivo("TempCrecMen");
            
            dataMeses += ("\n" + CrecimientoMensual);
            
            EscribirArchivo("TempCrecMen", dataMeses);
         }
      }
      else
      {
         balanceActual = AccountBalance();
         EscribirArchivo("TempCapIniM", DoubleToStr(balanceActual));
         EscribirArchivo("TempCapIniW", DoubleToStr(balanceActual));
         EscribirArchivo("TempCrecMen", "0");
         EscribirArchivo("TempCrecSem", "0");
      }
   }
   
   else return;
}

string LeerArchivo(string path)
{
   int f_Handle = FileOpen(path,1, 0,0);
   
   string data = "";
   
   while(FileIsEnding(f_Handle)) data += FileReadString(f_Handle);
   
   FileClose(f_Handle);
   
   return data;
   
}

void EscribirArchivo(string path, string data)
{
   string exten = ".txt";
   path = "C:\\Users\\Binary\\Desktop\\" + path + exten;
   int fHandle = FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT);
   uint create = FileWriteString(fHandle, data);   
   FileClose(fHandle);
   if(create == 0) printf("ERROR: " + GetLastError());
}
//+------------------------------------------------------------------+