dnl Autoconf configure script for Ada Embedded Network

AC_INIT(Makefile.in)

AC_CANONICAL_SYSTEM
AC_EXEEXT

# Current release settings
ANET_MAJOR_VERSION=1
ANET_MINOR_VERSION=0
ANET_MICRO_VERSION=0
ANET_VERSION=$ANET_MAJOR_VERSION.$ANET_MINOR_VERSION.$ANET_MICRO_VERSION

# Set the version number of GtkAda
AC_SUBST(ANET_VERSION)
AC_SUBST(ANET_MAJOR_VERSION)
AC_SUBST(ANET_MINOR_VERSION)
AC_SUBST(ANET_MICRO_VERSION)

EXEC_PREFIX="$prefix"
AC_SUBST(EXEC_PREFIX)

AC_ARG_WITH(board,
  AS_HELP_STRING([--with-board=NAME], [Define the board to be used]),
  [
    anet_board=${withval}
  ],
  [
    anet_board=stm32f746
  ])

AC_ARG_WITH(ada-drivers,
  AS_HELP_STRING([--with-ada-drivers=PATH], [Define the path for Ada Drivers Library]),
  [
    DRIVERS_PATH=${withval}
  ],
  [
    DRIVERS_PATH=Ada_Drivers_Library
  ])

case ${anet_board} in
  stm32f429)
    BOARD=stm32f429
    BOARD_DIR=stm32f429disco
    BOARD_SUBDIR=stm32f429_discovery
    BOARD_PROJECT=stm32f429_discovery_sfp
    BOARD_RUNTIME=STM32F429_Discovery_sfp
    ;;

  stm32f746)
    BOARD=stm32f746
    BOARD_DIR=stm32f746disco
    BOARD_SUBDIR=stm32f746_discovery
    BOARD_PROJECT=stm32f746_discovery_sfp
    BOARD_RUNTIME=STM32F746_Discovery_sfp
    ;;

  stm32f769)
    BOARD=stm32f769
    BOARD_DIR=stm32f769disco
    BOARD_SUBDIR=stm32f769_discovery
    BOARD_PROJECT=stm32f769_discovery_sfp
    BOARD_RUNTIME=STM32F769_Discovery_sfp
    ;;

  *)
    AC_MSG_ERROR([Boards ${anet_board} is not supported.  Please, use one of the following:

stm32f429
stm32f746
stm32f769
])
    ;;
esac

AC_SUBST(BOARD)
AC_SUBST(BOARD_DIR)
AC_SUBST(BOARD_PROJECT)
AC_SUBST(BOARD_SUBDIR)
AC_SUBST(BOARD_RUNTIME)
AC_SUBST(DRIVERS_PATH)

AC_OUTPUT(
Makefile ping.gpr dns.gpr time.gpr echo.gpr anet_stm32fxxx.gpr
)
