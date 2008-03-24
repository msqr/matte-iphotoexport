GSOAP_HOME=../../gsoap
GSOAP=$(GSOAP_HOME)/bin/soapcpp2
GWSDL=$(GSOAP_HOME)/bin/wsdl2h
SOAPH=$(GSOAP_HOME)/stdsoap2.h
SOAPC=$(GSOAP_HOME)/stdsoap2.c
SOAPCPP=$(GSOAP_HOME)/stdsoap2.cpp
CC=gcc
CPP=g++
LIBS=-lcrypto -lssl
COFLAGS=-O2
CWFLAGS=-Wall
CIFLAGS=-I. -I$(GSOAP_HOME) -I$(GSOAP_HOME)/plugin
CMFLAGS=-DWITH_DOM -DWITH_OPENSSL
CFLAGS= $(CWFLAGS) $(COFLAGS) $(CIFLAGS) $(CMFLAGS)
all:		matte
matte:	MatteService.h soapC.c $(SOAPH) $(SOAPC) $(GSOAP_HOME)/dom.c wsseapi.o smdevp.o
		$(CC) $(CFLAGS) -o MatteService MatteService.c soapC.c soapClient.c $(GSOAP_HOME)/dom.c $(SOAPC) wsseapi.o smdevp.o $(LIBS)
MatteService.h:	matte.wsdl
		$(GWSDL) -c -t typemap.dat -o MatteService.h matte.wsdl
soapC.c:	MatteService.h
		$(GSOAP) -c -I$(GSOAP_HOME)/import MatteService.h
wsseapi.o:	$(GSOAP_HOME)/plugin/wsseapi.h $(GSOAP_HOME)/plugin/wsseapi.c
		$(CC) $(CFLAGS) -c $(GSOAP_HOME)/plugin/wsseapi.c
smdevp.o:	$(GSOAP_HOME)/plugin/smdevp.h $(GSOAP_HOME)/plugin/smdevp.c
		$(CC) $(CFLAGS) -c $(GSOAP_HOME)/plugin/smdevp.c
clean:
		rm -f *.xml *.o soapH.h soapStub.h soapC.cpp soapC.c soapClient.cpp soapClient.c soapServer.cpp soapServer.c soap*Proxy.h soap*Object.h soapClientLib.c soapServerLib.c
distclean:
		rm -f *.o *.xml *.nsmap *.log soapH.h soapStub.h soapC.cpp soapC.c soapClient.cpp soapClient.c soapServer.cpp soapServer.c soapClientLib.c soapServerLib.c soap*Proxy.h soap*Object.h matte MatteService.h
