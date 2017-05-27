dnl Autoconf configure script for AWA

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

awa_build_root=
awa_xmlada_name=
awa_aws_name=
AC_ARG_WITH(board,
  AS_HELP_STRING([--with-board=NAME], [Define the board to be used]),
  [
    anet_board=${withval}
  ],
  [
    anet_board=stm32f746
  ])

case ${anet_board} in
  stm32f746)
    BOARD=stm32f746
    BOARD_DIR=stm32f746disco
    BOARD_PROJECT=stm32f746_discovery
    BOARD_RUNTIME=STM32F746_Discovery
    ;;

  stm32f769)
    BOARD=stm32f769
    BOARD_DIR=stm32f769disco
    BOARD_PROJECT=stm32f769_discovery
    BOARD_RUNTIME=STM32F769_Discovery
    ;;

  *)
    AC_MSG_ERROR([Boards ${anet_board} is not supported.  Please, use one of the following:

stm32f746
stm32f769
])
    ;;
esac

AC_SUBST(BOARD)
AC_SUBST(BOARD_DIR)
AC_SUBST(BOARD_PROJECT)
AC_SUBST(BOARD_RUNTIME)

AC_OUTPUT(
Makefile ping.gpr dns.gpr time.gpr echo.gpr anet_stm32fxxx.gpr
)
