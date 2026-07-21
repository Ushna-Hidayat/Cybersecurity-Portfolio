; ============================================================
;   ATM SYSTEM - Assembly Language Project (EMU8086)
;   Features: PIN Login, Balance Check, Deposit,
;             Withdraw, Mini Statement, Change PIN
; ============================================================

.MODEL SMALL
.STACK 100H

.DATA
    ; ---- Strings ----
    welcome     DB 13,10,"+--------------------------+",13,10
                DB "¦      WELCOME TO ATM       ¦",13,10
                DB "+--------------------------+",13,10,"$"

    menuMsg     DB 13,10,"========== MAIN MENU ==========",13,10
                DB " 1. Check Balance",13,10
                DB " 2. Deposit Money",13,10
                DB " 3. Withdraw Money",13,10
                DB " 4. Change PIN",13,10
                DB " 5. Mini Statement",13,10
                DB " 6. Exit",13,10
                DB "================================",13,10
                DB "Enter choice: $"

    pinPrompt   DB 13,10,"Enter 4-digit PIN: $"
    newPinMsg   DB 13,10,"Enter NEW 4-digit PIN: $"
    confirmPin  DB 13,10,"Confirm new PIN: $"

    balMsg      DB 13,10,">> Current Balance: Rs. $"
    depositMsg  DB 13,10,"Enter deposit amount: Rs. $"
    withdrawMsg DB 13,10,"Enter withdrawal amount: Rs. $"

    successMsg  DB 13,10,"[SUCCESS] Transaction Complete!",13,10,"$"
    wrongPin    DB 13,10,"[ERROR] Wrong PIN! Try again.",13,10,"$"
    invalidMsg  DB 13,10,"[ERROR] Invalid choice!",13,10,"$"
    insuffMsg   DB 13,10,"[ERROR] Insufficient Balance!",13,10,"$"
    pinChanged  DB 13,10,"[SUCCESS] PIN Changed Successfully!",13,10,"$"
    pinMismatch DB 13,10,"[ERROR] PINs do not match!",13,10,"$"
    byeMsg      DB 13,10,"Thank you for using our ATM!",13,10
                DB "Please collect your card.",13,10,"$"
    attemptsMsg DB 13,10,"[BLOCKED] Too many wrong attempts! Card blocked.",13,10,"$"
    newline     DB 13,10,"$"

    stmtHeader  DB 13,10,"===== MINI STATEMENT =====",13,10,"$"
    stmtDeposit DB " + Deposited: Rs. $"
    stmtWithdraw DB " - Withdrew:  Rs. $"
    stmtNone    DB " No transactions yet.",13,10,"$"
    stmtEnd     DB "==========================",13,10,"$"

    pressKey    DB 13,10,"Press any key to continue...$"

    ; ---- Data Variables ----
    pin         DW 1234        ; Default PIN
    balance     DW 5000        ; Starting balance Rs. 5000
    attempts    DB 0           ; Wrong PIN attempt counter
    maxAttempts DB 3

    ; Transaction log (last 3 transactions: type + amount)
    ; type: 'D'=deposit, 'W'=withdraw, 0=empty
    txType1     DB 0
    txAmt1      DW 0
    txType2     DB 0
    txAmt2      DW 0
    txType3     DB 0
    txAmt3      DW 0

    ; Temp input buffer
    inputBuf    DW 0
    pinBuf1     DW 0
    pinBuf2     DW 0

; ============================================================
.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Show welcome screen
    LEA DX, welcome
    CALL PRINT_STR

    ; PIN login loop
LOGIN_LOOP:
    LEA DX, pinPrompt
    CALL PRINT_STR

    CALL READ_NUMBER
    MOV pinBuf1, AX

    ; Check attempts
    MOV AL, attempts
    CMP AL, maxAttempts
    JAE BLOCKED

    ; Compare with stored PIN
    MOV AX, pinBuf1
    CMP AX, pin
    JE  PIN_OK

    ; Wrong PIN
    INC attempts
    LEA DX, wrongPin
    CALL PRINT_STR
    JMP LOGIN_LOOP

BLOCKED:
    LEA DX, attemptsMsg
    CALL PRINT_STR
    JMP EXIT_PROG

PIN_OK:
    MOV attempts, 0    ; Reset counter on success

; ============================================================
MENU_LOOP:
    LEA DX, menuMsg
    CALL PRINT_STR

    ; Read single key
    MOV AH, 01H
    INT 21H
    ; AL = char entered

    CMP AL, '1'
    JE  CHECK_BAL
    CMP AL, '2'
    JE  DEPOSIT
    CMP AL, '3'
    JE  WITHDRAW
    CMP AL, '4'
    JE  CHANGE_PIN
    CMP AL, '5'
    JE  MINI_STMT
    CMP AL, '6'
    JE  EXIT_PROG

    LEA DX, invalidMsg
    CALL PRINT_STR
    JMP MENU_LOOP

; ---- 1. CHECK BALANCE ----
CHECK_BAL:
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, balMsg
    CALL PRINT_STR
    MOV AX, balance
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, pressKey
    CALL PRINT_STR
    MOV AH, 01H
    INT 21H
    JMP MENU_LOOP

; ---- 2. DEPOSIT ----
DEPOSIT:
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, depositMsg
    CALL PRINT_STR
    CALL READ_NUMBER
    MOV inputBuf, AX

    ; amount must be > 0
    CMP AX ,0   ;means deposit value cant be 0 or negative
    JLE MENU_LOOP

    ; Add to balance
    ADD balance, AX

    ; Log transaction (shift log)
    CALL LOG_DEPOSIT

    LEA DX, successMsg
    CALL PRINT_STR
    LEA DX, balMsg
    CALL PRINT_STR
    MOV AX, balance
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, pressKey
    CALL PRINT_STR
    MOV AH, 01H
    INT 21H
    JMP MENU_LOOP

; ---- 3. WITHDRAW ----
WITHDRAW:
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, withdrawMsg
    CALL PRINT_STR
    CALL READ_NUMBER
    MOV inputBuf, AX

    CMP AX, 0
    JLE MENU_LOOP

    ; Check balance
    CMP AX, balance
    JA  INSUFF_BAL

    SUB balance, AX

    ; Log transaction
    CALL LOG_WITHDRAW

    LEA DX, successMsg
    CALL PRINT_STR
    LEA DX, balMsg
    CALL PRINT_STR
    MOV AX, balance
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, pressKey
    CALL PRINT_STR
    MOV AH, 01H
    INT 21H
    JMP MENU_LOOP

INSUFF_BAL:
    LEA DX, insuffMsg
    CALL PRINT_STR
    JMP MENU_LOOP

; ---- 4. CHANGE PIN ----
CHANGE_PIN:
    LEA DX, newPinMsg
    CALL PRINT_STR
    CALL READ_NUMBER
    MOV pinBuf1, AX

    LEA DX, confirmPin
    CALL PRINT_STR
    CALL READ_NUMBER
    MOV pinBuf2, AX

    MOV AX, pinBuf1
    CMP AX, pinBuf2
    JNE PIN_MISMATCH

    ; Validate: must be 4-digit (1000-9999)
    CMP AX, 1000
    JL  PIN_MISMATCH
    CMP AX, 9999
    JG  PIN_MISMATCH

    MOV pin, AX
    LEA DX, pinChanged
    CALL PRINT_STR
    JMP MENU_LOOP

PIN_MISMATCH:
    LEA DX, pinMismatch
    CALL PRINT_STR
    JMP MENU_LOOP

; ---- 5. MINI STATEMENT ----
MINI_STMT:
    LEA DX, stmtHeader
    CALL PRINT_STR

    ; Check if any transactions exist
    MOV AL, txType1
    CMP AL, 0
    JE  NO_TXNS

    ; Print tx3 (oldest) -> tx2 -> tx1 (latest)
    MOV AL, txType3
    CMP AL, 0
    JE  PRINT_TX2
    CALL PRINT_TX_3

PRINT_TX2:
    MOV AL, txType2
    CMP AL, 0
    JE  PRINT_TX1
    CALL PRINT_TX_2

PRINT_TX1:
    MOV AL, txType1
    CMP AL, 0
    JE  STMT_END_LBL
    CALL PRINT_TX_1
    JMP STMT_END_LBL

NO_TXNS:
    LEA DX, stmtNone
    CALL PRINT_STR

STMT_END_LBL:
    LEA DX, balMsg
    CALL PRINT_STR
    MOV AX, balance
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    LEA DX, stmtEnd
    CALL PRINT_STR
    LEA DX, pressKey
    CALL PRINT_STR
    MOV AH, 01H
    INT 21H
    JMP MENU_LOOP

; ---- EXIT ----
EXIT_PROG:
    LEA DX, byeMsg
    CALL PRINT_STR
    MOV AH, 4CH
    INT 21H

MAIN ENDP

; ============================================================
; SUBROUTINE: PRINT_STR  (DX = address of $-terminated string)
; ============================================================
PRINT_STR PROC
    MOV AH, 09H
    INT 21H
    RET
PRINT_STR ENDP

; ============================================================
; SUBROUTINE: READ_NUMBER
; Reads up to 5 digits from keyboard, returns value in AX
; ============================================================
READ_NUMBER PROC
    PUSH BX
    PUSH CX
    MOV BX, 0       ; accumulator
    MOV CX, 0       ; digit count
                                  
READ_LOOP:
    MOV AH, 01H
    INT 21H         ; read char into AL

    CMP AL, 13      ; Enter key?
    JE  READ_DONE
    CMP AL, 8       ; Backspace?
    JE  BACKSPACE

    ; Check digit
    CMP AL, '0'
    JL  READ_LOOP
    CMP AL, '9'
    JG  READ_LOOP

    ; Limit 5 digits
    CMP CX, 5
    JAE READ_LOOP

    SUB AL, '0'
    MOV AH, 0

    ; BX = BX*10 + digit
    PUSH AX
    MOV AX, BX
    MOV DX, 10
    MUL DX          ; DX:AX = BX * 10
    MOV BX, AX
    POP AX
    ADD BX, AX
    INC CX
    JMP READ_LOOP

BACKSPACE:
    CMP CX, 0
    JE  READ_LOOP
    ; Remove last digit
    MOV AX, BX
    MOV DX, 0
    MOV SI, 10
    DIV SI          ; AX = BX/10
    MOV BX, AX
    DEC CX
    ; Erase char on screen
    MOV AH, 02H
    MOV DL, 8
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, 8
    INT 21H
    JMP READ_LOOP

READ_DONE:
    MOV AX, BX
    POP CX
    POP BX
    RET
READ_NUMBER ENDP

; ============================================================
; SUBROUTINE: PRINT_NUM  (AX = number to print)
; ============================================================
PRINT_NUM PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV BX, 10
    MOV CX, 0

    ; Handle 0
    CMP AX, 0
    JNE PN_LOOP
    MOV AH, 02H
    MOV DL, '0'
    INT 21H
    JMP PN_DONE

PN_LOOP:
    CMP AX, 0
    JE  PN_PRINT
    MOV DX, 0
    DIV BX          ; AX = AX/10, DX = remainder
    PUSH DX
    INC CX
    JMP PN_LOOP

PN_PRINT:
    CMP CX, 0
    JE  PN_DONE
    POP DX
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    DEC CX
    JMP PN_PRINT

PN_DONE:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP

; ============================================================
; SUBROUTINE: LOG_DEPOSIT - shift log and add deposit entry
; ============================================================
LOG_DEPOSIT PROC
    ; Shift: tx2->tx3, tx1->tx2
    MOV AL, txType2
    MOV txType3, AL
    MOV AX, txAmt2
    MOV txAmt3, AX

    MOV AL, txType1
    MOV txType2, AL
    MOV AX, txAmt1
    MOV txAmt2, AX

    ; New entry
    MOV txType1, 'D'
    MOV AX, inputBuf
    MOV txAmt1, AX
    RET
LOG_DEPOSIT ENDP

; ============================================================
; SUBROUTINE: LOG_WITHDRAW
; ============================================================
LOG_WITHDRAW PROC
    MOV AL, txType2
    MOV txType3, AL
    MOV AX, txAmt2
    MOV txAmt3, AX

    MOV AL, txType1
    MOV txType2, AL
    MOV AX, txAmt1
    MOV txAmt2, AX

    MOV txType1, 'W'
    MOV AX, inputBuf
    MOV txAmt1, AX
    RET
LOG_WITHDRAW ENDP

; ============================================================
; Print individual transaction entries
; ============================================================
PRINT_TX_1 PROC
    MOV AL, txType1
    CMP AL, 'D'
    JE  PT1_DEP
    LEA DX, stmtWithdraw
    CALL PRINT_STR
    MOV AX, txAmt1
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    RET
PT1_DEP:
    LEA DX, stmtDeposit
    CALL PRINT_STR
    MOV AX, txAmt1
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    RET
PRINT_TX_1 ENDP

PRINT_TX_2 PROC
    MOV AL, txType2
    CMP AL, 'D'
    JE  PT2_DEP
    LEA DX, stmtWithdraw
    CALL PRINT_STR
    MOV AX, txAmt2
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    RET
PT2_DEP:
    LEA DX, stmtDeposit
    CALL PRINT_STR
    MOV AX, txAmt2
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    RET
PRINT_TX_2 ENDP

PRINT_TX_3 PROC
    MOV AL, txType3
    CMP AL, 'D'
    JE  PT3_DEP
    LEA DX, stmtWithdraw
    CALL PRINT_STR
    MOV AX, txAmt3
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    RET
PT3_DEP:
    LEA DX, stmtDeposit
    CALL PRINT_STR
    MOV AX, txAmt3
    CALL PRINT_NUM
    LEA DX, newline
    CALL PRINT_STR
    RET
PRINT_TX_3 ENDP

END MAIN