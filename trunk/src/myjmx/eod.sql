CREATE OR REPLACE PACKAGE BODY eodproc
AS
/* $Header: eodpkgb.sql 2.7 06SEP2008 Angelo Nuestro $ */
-- v3.0 - Bugzillar no. 1687: Refine Refresh User update Date Reset Password Updated and 
--        Refresh User only valid for company 2, 3.
-- v2.9 - add refreshUser procedure to handle the different scenario for user creation/inactivation.
-- v2.8 - Change 'default' date of NewFrontendUseridCreation and variable of open cursor for Account
-- v2.7 - 08SEP08 agnuestro
--      - added commit to NewFrontendUseridCreation
-- v2.6 - 04SEP08 agnuestro
--      - TransactionNotification fix
-- v2.5 - 01SEP08 agnuestro
--      - EOD 4.7 - populated r_customer.customer_type, r_customer.auth_type
--      -           and r_custuser_matrix.relationship
--      - Modified EOD 4.12 - RefreshTrxDescription
-- v2.4 - 27aug08 agnuestro
--      - TransactionNotification fix
--      - added RefreshTrxDescription
-- v2.3 - 26aug08 agnuestro
--      - added RefreshTrxDescription process
-- v2.2 - 26aug08 agnuestro
--      - modifications for MassEmailAnnualReport unit test
-- v2.1 - 23aug08 agnuestro
--      - modifications based on AVIVA TSD - System Architecture - EOD_v7.doc
-- v2.0 - 18aug08 agnuestro
--      - added massemailannualreport procedure
-- v1.7 - 12aug08 agnuestro
--      - modifications based on AVIVA TSD - System Architecture - EOD_v6.doc
-- v1.6 - 07aug08 agnuestro
--      - 4.10 checks fdbkind of all funds for the ztranref
-- v1.5 - 04aug08 agnuestro
--      - modifications to fit EOD_Testing_doc
   -- Audit trail variables
   v_action     VARCHAR2 (10);
   v_table_nm   VARCHAR2 (100);
   v_before     VARCHAR2 (4000);                           -- value for DATA1
   v_after      VARCHAR2 (4000);                           -- value for DATA2
   PROCEDURE delexptrnreqwoapp
   IS
      -- 4.1 Delete Expired Transaction and Request without approval
      v_pendingapproval_days   r_sysparam.VALUE%TYPE;
      r_pa                     pending_approval%ROWTYPE;
      CURSOR c_pa (p_pendingapproval_days IN NUMBER)
      IS
         SELECT *
           FROM pending_approval pa
          WHERE (SYSDATE - pa.DT_SUBMITTED) >= p_pendingapproval_days
            AND pa.pending_status = 'PND'
            AND EXISTS (SELECT '1'
                          FROM trx_ut a
                         WHERE a.pending_approval_id = pa.pending_approval_id);
      CURSOR c_pa_admin (p_pendingapproval_days IN NUMBER)
      IS
         SELECT *
           FROM pending_approval pa
          WHERE (SYSDATE - pa.DT_SUBMITTED) >= p_pendingapproval_days
            AND pa.pending_type != 'TRA'
            AND pa.pending_status = 'PND';
   BEGIN
      SELECT VALUE
        INTO v_pendingapproval_days
        FROM r_sysparam
       WHERE param_code = 'PENDINGAPPROVAL_DAYS';
      -- add effective date and status conditions if required
      OPEN c_pa (v_pendingapproval_days);
      LOOP
         FETCH c_pa
          INTO r_pa;
         EXIT WHEN c_pa%NOTFOUND;
         DELETE FROM trx_ut_detail b
               WHERE b.trx_ut_id IN (
                        SELECT a.trx_ut_id
                          FROM trx_ut a
                         WHERE a.pending_approval_id =
                                                     r_pa.pending_approval_id);
         DELETE FROM trx_ut a
               WHERE a.pending_approval_id = r_pa.pending_approval_id;
         DELETE FROM PENDING_APPROVAL_HISTORY a
                      WHERE a.pending_approval_id = r_pa.pending_approval_id;
         DELETE FROM pending_approval a
               WHERE a.pending_approval_id = r_pa.pending_approval_id;
         v_action := 'EOD4.1';
         v_table_nm := 'PENDING_APPROVAL';
         v_before :=
               TO_CHAR (r_pa.pending_approval_id)
            || '|'
            || TO_CHAR (r_pa.pending_type)
            || '|'
            || r_pa.pending_status
            || '|'
            || r_pa.submitted_by
            || '|'
            || TO_CHAR (r_pa.dt_submitted)
            || '|'
            || r_pa.updated_by
            || '|'
            || TO_CHAR (r_pa.dt_updated)
            || '|'
            || TO_CHAR (r_pa.ref_pending_approval_id)
            || '|'
            || TO_CHAR (r_pa.next_approver_id1)
            || '|'
            || TO_CHAR (r_pa.next_approver_id2);
         v_after := '';
         eodproc.insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_pa;
      OPEN c_pa_admin (v_pendingapproval_days);
      LOOP
         FETCH c_pa_admin
          INTO r_pa;
         EXIT WHEN c_pa_admin%NOTFOUND;
         UPDATE pending_approval a
            SET pending_status = 'EXP'
          WHERE a.pending_approval_id = r_pa.pending_approval_id;
         v_action := 'EOD4.1';
         v_table_nm := 'PENDING_APPROVAL';
         v_before :=
               TO_CHAR (r_pa.pending_approval_id)
            || '|'
            || TO_CHAR (r_pa.pending_type)
            || '|'
            || r_pa.pending_status
            || '|'
            || r_pa.submitted_by
            || '|'
            || TO_CHAR (r_pa.dt_submitted)
            || '|'
            || r_pa.updated_by
            || '|'
            || TO_CHAR (r_pa.dt_updated)
            || '|'
            || TO_CHAR (r_pa.ref_pending_approval_id)
            || '|'
            || TO_CHAR (r_pa.next_approver_id1)
            || '|'
            || TO_CHAR (r_pa.next_approver_id2);
         v_after :=
               TO_CHAR (r_pa.pending_approval_id)
            || '|'
            || TO_CHAR (r_pa.pending_type)
            || '|'
            || 'EXP'
            || '|'
            || r_pa.submitted_by
            || '|'
            || TO_CHAR (r_pa.dt_submitted)
            || '|'
            || TO_CHAR (SYSDATE)
            || '|'
            || TO_CHAR (r_pa.dt_updated)
            || '|'
            || TO_CHAR (r_pa.ref_pending_approval_id)
            || '|'
            || TO_CHAR (r_pa.next_approver_id1)
            || '|'
            || TO_CHAR (r_pa.next_approver_id2);
         eodproc.insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_pa_admin;
      inserteodlog ('DelExpTrnReqWOApp', 'S');
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_pa%ISOPEN  THEN CLOSE c_pa ; END IF;
        IF c_pa_admin%ISOPEN  THEN CLOSE c_pa_admin ; END IF;
         inserteodlog ('DelExpTrnReqWOApp', 'F', SQLERRM);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE deletemailbox
   IS
      -- 4.2 Delete Mailbox
      v_mailmaxmonthadmin         r_sysparam.VALUE%TYPE;
      v_mailmaxmessagesadmin      r_sysparam.VALUE%TYPE;
      v_mailmaxmonthnonadmin      r_sysparam.VALUE%TYPE;
      v_mailmaxmessagesnonadmin   r_sysparam.VALUE%TYPE;
      r_mail_id                   mail.mail_id%TYPE;
      r_to                        VARCHAR2 (4000);
      r_from                      VARCHAR2 (50);
      r_subject                   mail.subject%TYPE;
      r_dt_created                mail.dt_created%TYPE;
      CURSOR c_mail (
         p_mailmaxmonthadmin         IN   NUMBER,
         p_mailmaxmessagesadmin      IN   NUMBER,
         p_mailmaxmonthnonadmin      IN   NUMBER,
         p_mailmaxmessagesnonadmin   IN   NUMBER
      )
      IS
         SELECT DISTINCT mail_id, subject, dt_created
                    FROM (SELECT a.mail_id, a.subject, a.dt_created
                            FROM mail a, r_user_info b
                           WHERE a.owner_id = b.user_id
                             AND (SYSDATE - a.dt_created) >=
                                    DECODE (b.user_type,
                                            'I', v_mailmaxmonthadmin,
                                            v_mailmaxmonthnonadmin
                                           )
                          UNION ALL
                          SELECT x.mail_id, x.subject, x.dt_created
                            FROM mail x, r_user_info y
                           WHERE x.owner_id = y.user_id
                             AND DECODE (y.user_type,
                                         'I', v_mailmaxmessagesadmin,
                                         v_mailmaxmessagesnonadmin
                                        ) <=
                                    (SELECT COUNT (*)
                                       FROM mail z
                                      WHERE z.owner_id = x.owner_id
                                        AND z.dt_created > x.dt_created));
   BEGIN
      SELECT VALUE
        INTO v_mailmaxmonthadmin
        FROM r_sysparam
       WHERE param_code = 'MAIL_MAX_DAYS_ADMIN';
      -- add effective date and status conditions if required
      SELECT VALUE
        INTO v_mailmaxmessagesadmin
        FROM r_sysparam
       WHERE param_code = 'MAIL_MAX_MESSAGES_ADMIN';
      -- add effective date and status conditions if required
      SELECT VALUE
        INTO v_mailmaxmonthnonadmin
        FROM r_sysparam
       WHERE param_code = 'MAIL_MAX_DAYS_NON_ADMIN';
      -- add effective date and status conditions if required
      SELECT VALUE
        INTO v_mailmaxmessagesnonadmin
        FROM r_sysparam
       WHERE param_code = 'MAIL_MAX_MESSAGES_NON_ADMIN';
      -- add effective date and status conditions if required
      --
      -- Run through the owner_id's
      --
      OPEN c_mail (v_mailmaxmonthadmin,
                   v_mailmaxmessagesadmin,
                   v_mailmaxmonthnonadmin,
                   v_mailmaxmessagesnonadmin
                  );
      LOOP
         FETCH c_mail
          INTO r_mail_id, r_subject, r_dt_created;
         EXIT WHEN c_mail%NOTFOUND;
     DELETE FROM mail_dtl_content c
               WHERE c.mail_id = r_mail_id;
         DELETE FROM mail_dtl a
               WHERE a.mail_id = r_mail_id;
         DELETE FROM mail b
               WHERE b.mail_id = r_mail_id;
         v_action := 'DeleteMB';
         v_table_nm := 'MAIL,MAIL.DTL';
         v_before :=
                TO_CHAR (r_mail_id) || '|' || r_dt_created
--                      ||'|'||r_to
--                      ||'|'||r_from
                || '|' || r_subject;
         v_after := '';
         insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_mail;
      inserteodlog ('DeleteMailbox', 'S');
      --EODPROC.sendNotification(--enter notification parameters);
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_mail%ISOPEN  THEN CLOSE c_mail ; END IF;
         inserteodlog ('DeleteMailbox', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE alertbyfund
   IS
      -- 4.3 Alert by Fund
      r_fund_alert_id   fund_alert.fund_alert_id%TYPE;
      r_user_id         fund_alert.user_id%TYPE;
      r_floor           fund_alert.FLOOR%TYPE;
      r_ceiling         fund_alert.ceiling%TYPE;
      r_ubidpr          ifsdmvprcpf.ubidpr%TYPE;
      CURSOR c_fund
      IS
         SELECT a.fund_alert_id, a.user_id, a.FLOOR, a.ceiling, b.ubidpr
           FROM fund_alert a, ifsdmvprcpf b
          WHERE TO_CHAR (a.fund_alert_id) = b.vrtfnd      -- for verification
            AND (b.ubidpr <= a.FLOOR OR b.ubidpr >= a.ceiling)
            AND b.effdate = (SELECT MAX (c.effdate)    -- get the latest price
                               FROM ifsdmvprcpf c
                              WHERE c.vrtfnd = b.vrtfnd);
   BEGIN
      --
      -- Run through the FUND_ALERT
      --
      OPEN c_fund;
      LOOP
         FETCH c_fund
          INTO r_fund_alert_id, r_user_id, r_floor, r_ceiling, r_ubidpr;
         EXIT WHEN c_fund%NOTFOUND;
      --send message to user mailbox;
      --EODPROC.insertAuditLog(-- enter log parameters);
      END LOOP;
      CLOSE c_fund;
      inserteodlog ('AlertByFund', 'S');
      --EODPROC.sendNotification(--enter notification parameters);
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_fund%ISOPEN  THEN CLOSE c_fund ; END IF;
         inserteodlog ('AlertByFund', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE alertbyplanaccount
   IS
      -- 4.4 Alert by Plan Account
      CURSOR c_plan
      IS
         SELECT a.acct_id, a.user_id, a.FLOOR, a.ceiling
           --, c.UBIDPR
         FROM   acct_alert a, plan_acct b, ifsdmlzubpf c;
       /*
       IFSDMCHDRPF
       IFSDMVPRCPF
       IFSDMT5515PF
       IFSDMLZRTPF
      where a.ACCT_ID = b.ACCT_ID
        and (  b.UBIDPR =< a.FLOOR
            or b.UBIDPR => a.CEILING)
        and b.EFFDATE = (select max(c.EFFDATE)
                           from IFSDMVPRCP c
                          where c.VRTFND=b.VRTFND);
                          */
      r_fund_alert_id   fund_alert.fund_alert_id%TYPE;
      r_user_id         fund_alert.user_id%TYPE;
      r_floor           fund_alert.FLOOR%TYPE;
      r_ceiling         fund_alert.ceiling%TYPE;
      r_ubidpr          ifsdmvprcpf.ubidpr%TYPE;
   BEGIN
      --
      -- Run through the FUND_ALERT
      --
      OPEN c_plan;
      LOOP
         FETCH c_plan
          INTO r_fund_alert_id, r_user_id, r_floor, r_ceiling;
         --, r_ubidpr;
         EXIT WHEN c_plan%NOTFOUND;
      --send message to user mailbox;
      --EODPROC.insertAuditLog(-- enter log parameters);
      END LOOP;
      CLOSE c_plan;
      inserteodlog ('AlertByPlanAccount', 'S');
      --EODPROC.sendNotification(--enter notification parameters);
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_plan%ISOPEN  THEN CLOSE c_plan ; END IF;
         inserteodlog ('AlertByPlanAccount', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE archivetransactionhistory
   IS
      -- 4.5 Archive Transaction History
      v_trxhistorydurationmonth   r_sysparam.VALUE%TYPE;
      rw_trx_ut                   trx_ut%ROWTYPE;
      v_trx_id                    trx_ut.trx_ut_id%TYPE;
      CURSOR c_trx_ut (p_trxhistorydurationmonth IN NUMBER)
      IS
         SELECT *
           FROM trx_ut a
          WHERE (SYSDATE - a.dt_created) >= p_trxhistorydurationmonth;
      -- assumption: p_TrxHistoryDutationMonth is in days
      rw_trx_ut_dtl               trx_ut_detail%ROWTYPE;
      v_trx_detail_id             trx_ut_detail.trx_ut_detail_id%TYPE;
      CURSOR c_trx_ut_dtl (p_trx_ut_id IN NUMBER)
      IS
         SELECT *
           FROM trx_ut_detail a
          WHERE trx_ut_id = p_trx_ut_id;

      rw_pnd                      PENDING_APPROVAL%ROWTYPE;
      v_pnd_id                    PENDING_APPROVAL.pending_approval_id%TYPE;

      CURSOR c_pnd (p_trxhistorydurationmonth IN NUMBER)
      IS
         SELECT *
           FROM PENDING_APPROVAL a
          WHERE PENDING_TYPE='TRA' AND
                (SYSDATE - a.dt_submitted) >= p_trxhistorydurationmonth;
      -- assumption: p_TrxHistoryDutationMonth is in days
      rw_pnd_h                    pending_approval_history%ROWTYPE;
      CURSOR c_pnd_h (p_pnd_id IN NUMBER)
      IS
         SELECT *
           FROM pending_approval_history a
          WHERE pending_approval_id = p_pnd_id;
   BEGIN
       dbms_output.put_line('Start archive trx');
      SELECT VALUE
        INTO v_trxhistorydurationmonth
        FROM r_sysparam
       WHERE param_code = 'TRX_HISTORY_DURATION_MONTH';
      -- add effective date and status conditions if required
      OPEN c_trx_ut (v_trxhistorydurationmonth);
      LOOP
         FETCH c_trx_ut
          INTO rw_trx_ut;
         EXIT WHEN c_trx_ut%NOTFOUND;
         v_trx_id := rw_trx_ut.trx_ut_id;
         OPEN c_trx_ut_dtl (v_trx_id);
         LOOP
            FETCH c_trx_ut_dtl
             INTO rw_trx_ut_dtl;
            EXIT WHEN c_trx_ut_dtl%NOTFOUND;
            v_trx_detail_id := rw_trx_ut_dtl.trx_ut_detail_id;
            INSERT INTO trx_ut_detail_hist
                        (trx_ut_detail_id, trx_ut_id, trx_ut_detail_type,
                         fund_id, amount, unit, allocation, fee_upfront,
                         fee_establishment, fee_switching, redemption_method,
                         created_by, dt_created, updated_by, dt_updated)
               SELECT trx_ut_detail_id, trx_ut_id, trx_ut_detail_type,
                      fund_id, amount, unit, allocation, fee_upfront,
                      fee_establishment, fee_switching, redemption_method,
                      created_by, dt_created, updated_by, dt_updated
                 FROM trx_ut_detail a
                WHERE a.trx_ut_detail_id = v_trx_detail_id;
dbms_output.put_line('Start archive trx - delete from  trx_ut_detail ' || v_trx_detail_id );
            DELETE FROM trx_ut_detail a
                  WHERE a.trx_ut_detail_id = v_trx_detail_id;
            v_action := 'HkpTrnHist';
            v_table_nm := 'TRX_UT_DETAIL';
            v_before := 'TRX_UT_DETAIL ' || v_trx_detail_id;
            v_after := 'TRX_UT_DETAIL_HIST ' || v_trx_detail_id;
            insertauditlog (v_action, v_table_nm, v_before, v_after);
         END LOOP;
         CLOSE c_trx_ut_dtl;
dbms_output.put_line('Start archive trx - insert into trx_ut_hist' );
dbms_output.put_line('Start archive trx - insert into trx_ut_hist ' || v_trx_id);
         INSERT INTO trx_ut_hist
                     (trx_ut_id, reference_id, new_account_flag, account_id,
                      trx_type, trx_status, full_redemption_flag, dt_trx,
                      msg_to_cust, msg_to_fam, pending_approval_id,
                      total_amount, fee_switching, dt_created, frequency,
                      dt_start, payment_method, same_switching_fee_flag,
                      created_by, fee_structure_type, dt_updated, updated_by,
                      allocation_method, ongoing_fee, deferred_fee,
                      rejection_reason_fam, easy_save_deactivation_flag,
                      e_reference_number, rejection_reason_cust,
                      same_upfront_fee_flag, switch_to_account_id,
                      upfront_fee, bor, workflow, APPROVAL_REASON_FAM, APPROVAL_REASON_CUST1, APPROVAL_REASON_CUST2)
            SELECT trx_ut_id, reference_id, new_account_flag, account_id,
                   trx_type, trx_status, full_redemption_flag, dt_trx,
                   msg_to_cust, msg_to_fam, pending_approval_id, total_amount,
                   fee_switching, dt_created, frequency, dt_start,
                   payment_method, same_switching_fee_flag, created_by,
                   fee_stucture_type, dt_updated, updated_by,
                   allocation_method, ongoing_fee, deferred_fee,
                   rejection_reason_fam, easy_save_deactivation_flag,
                   e_reference_number, rejection_reason_cust,
                   same_upfront_fee_flag, switch_to_account_id, upfront_fee, bor,
                   workflow, APPROVAL_REASON_FAM, APPROVAL_REASON_CUST1, APPROVAL_REASON_CUST2
              FROM trx_ut a
             WHERE a.trx_ut_id = v_trx_id;
dbms_output.put_line('Start archive trx - delete from trx_ut_hist ' || v_trx_id);
         DELETE FROM trx_ut a
               WHERE a.trx_ut_id = v_trx_id;
         v_action := 'HkpTrnHist';
         v_table_nm := 'TRX_UT';
         v_before := 'TRX_UT ' || v_trx_id;
         v_after := 'TRX_UT_HIST ' || v_trx_id;

         DBMS_OUTPUT.PUT_LINE('Start archive trx - insert into audit log trx_ut_hist');

         insertauditlog (v_action, v_table_nm, v_before, v_after);

      END LOOP;

      CLOSE c_trx_ut;

dbms_output.put_line('Start archive trx --  move pending approval and history');
      -- Move pending_approval and pending_approval_history
      OPEN c_pnd (v_trxhistorydurationmonth);
      LOOP
         FETCH c_pnd
          INTO rw_pnd;
         EXIT WHEN c_pnd%NOTFOUND;
         v_pnd_id := rw_pnd.pending_approval_id;
         OPEN c_pnd_h (v_pnd_id);
         LOOP
            FETCH c_pnd_h
             INTO rw_pnd_h;
            EXIT WHEN c_pnd_h%NOTFOUND;
            INSERT INTO pending_approval_history_hist
               SELECT *
                 FROM pending_approval_history a
                WHERE a.pending_approval_id = v_pnd_id;
            DELETE FROM pending_approval_history a
                  WHERE a.pending_approval_id = v_pnd_id;
            v_action := 'HkpTrnHist';
            v_table_nm := 'PENDING_APPROVAL_HISTORY';
            v_before := 'PENDING_APPROVAL_HISTORY ' || v_pnd_id;
            v_after := 'PENDING_APPROVAL_HISTORY_HIST ' || v_pnd_id;
            insertauditlog (v_action, v_table_nm, v_before, v_after);
         END LOOP;
         CLOSE c_pnd_h;

         INSERT INTO PENDING_APPROVAL_HIST
            SELECT *
              FROM PENDING_APPROVAL a
             WHERE a.pending_approval_id = v_pnd_id;
         DELETE FROM pending_approval a
               WHERE a.pending_approval_id = v_pnd_id;
         v_action := 'HkpTrnHist';
         v_table_nm := 'TRX_UT';
         v_before := 'TRX_UT ' || v_trx_id;
         v_after := 'TRX_UT_HIST ' || v_trx_id;
         insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_pnd;
      inserteodlog ('HkpTrnHist', 'S');
   --EODPROC.sendNotification(--enter notification parameters);
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_trx_ut%ISOPEN  THEN CLOSE c_trx_ut ; END IF;
        IF c_trx_ut_dtl%ISOPEN  THEN CLOSE c_trx_ut_dtl ; END IF;
        IF c_pnd%ISOPEN  THEN CLOSE c_pnd ; END IF;
        IF c_pnd_h%ISOPEN  THEN CLOSE c_pnd_h ; END IF;
         inserteodlog ('HkpTrnHist', 'F', SQLERRM);
   --EODPROC.sendNotification(--enter notification parameters);
   --raise;
   ---- COMMIT;
   END;
   PROCEDURE setuseridtodormant
   IS
      -- 4.6 Set User id to Dormant except SADM
      v_dormantperioduser    r_sysparam.VALUE%TYPE;
      v_dormantperiodadmin   r_sysparam.VALUE%TYPE;
      v_pwd_regen_flag       r_user.pwd_regen_flag%TYPE;
      -- l_dormant            R_USER%rowtype;
      l_user_id              r_user.user_id%TYPE;
      l_status               r_user.status%TYPE;
      CURSOR c_dormant (
         p_dormantperioduser    IN   NUMBER,
         p_dormantperiodadmin   IN   NUMBER
      )
      IS
         SELECT a.user_id, a.status
           FROM r_user a, r_user_info b, r_user_role c, r_role d
          WHERE a.user_id = b.user_id
            AND SYSDATE - a.dt_last_login >=
                   DECODE (b.user_type,
                           'I', p_dormantperiodadmin,
                           p_dormantperioduser
                          )
            AND a.status != 'D'
   and c.USER_ID = a.USER_ID
   and c.ROLE_ID = d.ROLE_ID
   and d.ROLE_TYPE != 'S';
   BEGIN
      SELECT VALUE
        INTO v_dormantperioduser
        FROM r_sysparam
       WHERE param_code = 'DORMANT_PERIOD_USER';
      -- add effective date and status conditions if required
      SELECT VALUE
        INTO v_dormantperiodadmin
        FROM r_sysparam
       WHERE param_code = 'DORMANT_PERIOD_ADMIN';
      -- add effective date and status conditions if required
      OPEN c_dormant (v_dormantperioduser, v_dormantperiodadmin);
      LOOP
         FETCH c_dormant
          INTO l_user_id, l_status;
         EXIT WHEN c_dormant%NOTFOUND;
         UPDATE r_user b
            SET b.status = 'D',
                b.updated_by = 'EOD_PROCESS',
                b.dt_updated = SYSDATE
          WHERE b.user_id = l_user_id;
         v_action := 'DormantUID';
         v_table_nm := 'R_USER';
         v_before := l_user_id || '|' || l_status;
         v_after := l_user_id || '|' || 'D';
         insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_dormant;
      inserteodlog ('DormantUserID', 'S');
      --EODPROC.sendNotification(--enter notification parameters);
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_dormant%ISOPEN  THEN CLOSE c_dormant ; END IF;
         inserteodlog ('DormantUserID', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE newfrontenduseridcreation
   IS
      -- 4.7 New Frontend User id Creation
      /* r_customer.customer_type (CHDR)
         r_customer.auth_type
         r_custuser_matrix.relationship
      */
      v_eod_date_agent   eod_log.eod_date%TYPE;
      v_eod_date_user    eod_log.eod_date%TYPE;
      v_eod_date_acct    eod_log.eod_date%TYPE;
      rw_agent           ifsdmclntpf%ROWTYPE;
      rw_user            ifsdmclntpf%ROWTYPE;
      rw_acct            ifsdmchdrpf%ROWTYPE;
      r_erefnum          trx_ut.e_reference_number%TYPE;
      v_ctr              NUMBER;
      v_r_user_id        NUMBER;
      v_r_user_info_id   NUMBER;
      v_r_user_role_id   NUMBER;
      v_acctid           plan_acct.acctid%TYPE;
      lv_entity_id       r_custuser_matrix.entity_id%TYPE;
      --lv_chdr          IFSDMCHDRPF%rowtype;
      lv_ctr             NUMBER;
      lv_clnt1_ctr       NUMBER;
      lv_clnt2_ctr       NUMBER;
      lv_auth_type       r_customer.auth_type%TYPE;
      lv_clttype         ifsdmclntpf.clttype%TYPE;
      lv_customer_type   r_customer.customer_type%TYPE;
      lv_relationship    r_custuser_matrix.relationship%TYPE;
      lv_dueflg          ifsdmchdrpf.dueflg%TYPE;
      lv_plan_acct       NUMBER;
      lv_eref            NUMBER;
      debug_date         DATE;
      lv_e_ref_number    trx_ut.E_REFERENCE_NUMBER%TYPE;
      lv_user_status     r_user.status%TYPE;
      lv_pwd_regen_flag  r_user.pwd_regen_flag%TYPE;
      lv_email_ntfy_flg  r_user.email_notify_flag%TYPE;  --Added by sgarrk on 26/05/09 to Set Email Notification to Y
      lv_agnt_ctr       NUMBER;
      lv_inv_ctr         NUMBER;      
      --lv_countcom number := 0;
      CURSOR c_agent (p_eod_date_agent IN DATE)
      IS
         SELECT *
           FROM ifsdmclntpf a
          WHERE a.clntnum NOT IN (SELECT b.clntnum
                                    FROM r_user_info b
                                   WHERE b.clntnum = a.clntnum)
            AND a.datime > p_eod_date_agent
            AND a.cltmchg = 'Y'
            AND EXISTS (
                   SELECT 1
                     FROM ifsvwclnt_mst_ifs clnt, ifsvwadv_mst adv
                    WHERE adv.clnt_num = clnt.clnt_num
                      AND clnt.clnt_num = a.clntnum
                      AND ADV.TERMINATION_DATE > TO_CHAR(SYSDATE, 'YYYYMMDD')
                      );

      -- investor cursor
      CURSOR c_user (p_eod_date_user IN DATE)
      IS
         SELECT *
           FROM ifsdmclntpf a
          WHERE a.clntnum NOT IN (SELECT b.clntnum
                                    FROM r_user_info b
                                   WHERE b.clntnum = a.clntnum)
            AND a.datime > p_eod_date_user
          --AND a.cltmchg = 'Y'
            AND EXISTS (
                   SELECT 1 FROM IFSDMCHDRPF
                    where
                    IFSDMCHDRPF.statcode IN ('AC', 'IF')
     AND 
     IFSDMCHDRPF.chdrcoy IN ('2', '3')
                    AND
                    (IFSDMCHDRPF.COWNNUM = a.clntnum OR IFSDMCHDRPF.JOWNNUM = a.clntnum));

      CURSOR c_acct (p_eod_date_acct IN DATE)
      IS
         SELECT *
           FROM ifsdmchdrpf a
          WHERE NOT EXISTS (
                         SELECT acctid
                           FROM plan_acct b
                          WHERE b.chdrcoy = a.chdrcoy
                                AND b.chdrnum = a.chdrnum)
            AND a.statcode IN ('IF', 'AC')
            AND a.chdrcoy IN ('2', '3')
            AND a.modidate > TO_CHAR(p_eod_date_acct, 'YYYYMMDD');
      -- Portfolio cursor
      CURSOR c_portfolio(p_eod_date_acct IN DATE)
      IS
        select distinct a.e_reference_number
        from trx_ut a
        inner join ifsdmutrnpf b on trim(a.e_reference_number) = trim(b.ZTRANREF)
        inner join plan_acct c on b.chdrnum = c.chdrnum
        where exists (select 1 from tmp_portfolio d where d.account_temp_id = a.account_id)
        and not exists (select 1 from portfolio e where e.acct_id = c.acctid)
        and a.new_account_flag = 'Y'
        and b.trdt > to_char(p_eod_date_acct, 'YYYYMMDD');
   BEGIN
      -- New Agent
      SELECT COUNT (*)
        INTO v_ctr
        FROM eod_log
       WHERE eod_proc_name = 'NEW_AGENT' AND status = 'S';
      IF v_ctr > 0
      THEN
         SELECT MAX (eod_date)-5
           INTO v_eod_date_agent
           FROM eod_log
          WHERE eod_proc_name = 'NEW_AGENT' AND status = 'S';
      ELSE
         v_eod_date_agent := TO_DATE ('01-JAN-1990', 'DD-MON-YY');
      END IF;
      OPEN c_agent (v_eod_date_agent);
      LOOP
         FETCH c_agent
          INTO rw_agent;
         EXIT WHEN c_agent%NOTFOUND;
         /* Added by sgarrk on 26/05/2009 to set email notification to Y if email id is present */
         IF(trim(rw_agent.ZEMAILADD) IS NOT NULL ) THEN
          lv_email_ntfy_flg := 'Y';
         ELSE
          lv_email_ntfy_flg := 'N';
         END IF;

      -- Check if agent exsist
         SELECT COUNT (*)
           INTO lv_agnt_ctr
           FROM R_USER_INFO
          WHERE clntnum = rw_agent.clntnum;
   
         IF lv_agnt_ctr = 0 THEN
         INSERT INTO R_USER
                     (user_id, status, created_by, dt_created, pwd_regen_flag, email_notify_flag
                     )
              VALUES (seq_r_user.NEXTVAL, 'R', 'EOD-NEWFE', SYSDATE, 'Y', lv_email_ntfy_flg
                     );
         INSERT INTO r_user_info
                     (user_info_id, user_id, user_type,
                      clntnum, status, created_by, dt_created
                     )
              VALUES (seq_r_user_info.NEXTVAL, seq_r_user.CURRVAL, 'E',
                      rw_agent.clntnum, 'A', 'EOD-NEWFE', SYSDATE
                     );
         SELECT seq_r_user.CURRVAL
           INTO v_r_user_id
           FROM DUAL;
         SELECT seq_r_user_info.CURRVAL
           INTO v_r_user_info_id
           FROM DUAL;

         v_action := 'NEW_AGENT';
         v_table_nm := 'R_USER,R_USER_INFO';
         v_before := '';
         v_after :=
               TO_CHAR (v_r_user_id)
            || '|'
            || TO_CHAR (v_r_user_info_id)
            || '|'
            || rw_user.clntnum;
         insertauditlog (v_action, v_table_nm, v_before, v_after);
         END IF;
         
         --lv_countcom := lv_countcom + 1;
         --if lv_countcom > 1000 then
         -- lv_countcom :=0;
         -- commit;
         --end if;
      END LOOP;
      --commit;
      CLOSE c_agent;
      inserteodlog ('NEW_AGENT', 'S');
      -- New Investor
      SELECT COUNT (*)
        INTO v_ctr
        FROM eod_log
       WHERE eod_proc_name = 'NEW_USER' AND status = 'S';
      IF v_ctr > 0
      THEN
         SELECT MAX (eod_date)-5
           INTO v_eod_date_user
           FROM eod_log
          WHERE eod_proc_name = 'NEW_USER' AND status = 'S';
      ELSE
         v_eod_date_user := TO_DATE ('01-JAN-1990', 'DD-MON-YY');
      END IF;
      OPEN c_user (v_eod_date_user);
      LOOP
         FETCH c_user
          INTO rw_user;
         EXIT WHEN c_user%NOTFOUND;
        if(rw_user.cltmchg = 'Y')
        then
          lv_user_status := 'R';
          lv_pwd_regen_flag := 'Y';
        else
          lv_user_status := 'I';
          lv_pwd_regen_flag := 'N';
        end if;
         /* Added by sgarrk on 26/05/2009 to set email notification to Y if email id is present */
         IF(trim(rw_user.ZEMAILADD) IS NOT NULL ) THEN
          lv_email_ntfy_flg := 'Y';
         ELSE
          lv_email_ntfy_flg := 'N';
         END IF;        
        
         SELECT COUNT (*)
           INTO lv_inv_ctr
           FROM R_USER_INFO
         WHERE clntnum = rw_user.clntnum;
  
         IF lv_inv_ctr = 0
         THEN        
         INSERT INTO R_USER
                     (user_id, status, created_by, dt_created, pwd_regen_flag, email_notify_flag
                     )
              VALUES (seq_r_user.NEXTVAL, lv_user_status, 'EOD-NEWFE', SYSDATE, lv_pwd_regen_flag, lv_email_ntfy_flg
                     );
         INSERT INTO r_user_info
                     (user_info_id, user_id, user_type,
                      clntnum, status, created_by, dt_created
                     )
              VALUES (seq_r_user_info.NEXTVAL, seq_r_user.CURRVAL, 'E',
                      rw_user.clntnum, 'A', 'EOD-NEWFE', SYSDATE
                     );
         INSERT INTO r_user_role
                     (user_role_id, user_id,
                      role_id, status, created_by, dt_created
                     )
              VALUES (seq_r_user_role.NEXTVAL, seq_r_user.CURRVAL,
                      (SELECT role_id
                         FROM r_role
                        WHERE role_nm = 'INVESTOR'), 'A', 'EOD-NEWFE', SYSDATE
                     );
         SELECT seq_r_user.CURRVAL
           INTO v_r_user_id
           FROM DUAL;
         SELECT seq_r_user_info.CURRVAL
           INTO v_r_user_info_id
           FROM DUAL;
         SELECT seq_r_user_role.CURRVAL
           INTO v_r_user_role_id
           FROM DUAL;

         v_action := 'NEW_USER';
         v_table_nm := 'R_USER,R_USER_INFO,R_USER_ROLE';
         v_before := '';
         v_after :=
               TO_CHAR (v_r_user_id)
            || '|'
            || TO_CHAR (v_r_user_info_id)
            || '|'
            || TO_CHAR (v_r_user_role_id)
            || '|'
            || rw_user.clntnum;
         insertauditlog (v_action, v_table_nm, v_before, v_after);
         END IF;
         
         --lv_countcom := lv_countcom + 1;
         --if lv_countcom > 1000 then
         -- lv_countcom :=0;
         -- commit;
         --end if;
      END LOOP;
      --commit;
      CLOSE c_user;
      inserteodlog ('NEW_USER', 'S');
      -- New Plan_acct
      SELECT COUNT (*)
        INTO v_ctr
        FROM eod_log
       WHERE eod_proc_name = 'NEW_ACCT' AND status = 'S';
      IF v_ctr > 0
      THEN
         SELECT MAX (eod_date)-5
           INTO v_eod_date_acct
           FROM eod_log
          WHERE eod_proc_name = 'NEW_ACCT' AND status = 'S';
      ELSE
         v_eod_date_acct := TO_DATE ('01-JAN-1990', 'DD-MON-YY');
      END IF;
      OPEN c_acct (v_eod_date_acct);
      LOOP
         FETCH c_acct
          INTO rw_acct;
         EXIT WHEN c_acct%NOTFOUND;
         -- for debug purpose only - bsh
         DBMS_OUTPUT.put_line ('cownnum=' || rw_acct.cownnum);
         --if rw_acct.cownnum = '00630487'
         --then
         -- select sysdate into debug_date from dual;
         --end if;
         -- check if cownnum and jownum are already in r_user. If not, can not create plan_acct
         SELECT COUNT (*)
           INTO lv_clnt1_ctr
           FROM r_user_info
          WHERE clntnum = rw_acct.cownnum;
         IF lv_clnt1_ctr > 0
         THEN
            lv_clnt2_ctr := 1;       -- preset to in case there is no jownnum
            IF rw_acct.jownnum != '        '
            THEN
               SELECT COUNT (*)
                 INTO lv_clnt2_ctr
                 FROM r_user_info
                WHERE clntnum = rw_acct.jownnum;
            END IF;
            IF lv_clnt2_ctr > 0
            THEN
               -- set entity_id
               lv_entity_id := get_entity (rw_acct.cownnum, rw_acct.jownnum);
               -- prep the audit table variables
               v_table_nm := '';
               v_after := '';
               -- if there is no entity yet, create one
               IF lv_entity_id = -999
               THEN
                  IF rw_acct.jownnum = RPAD (' ', 8, ' ')
                  THEN
                     lv_auth_type := '';
                     SELECT clttype
                       INTO lv_clttype
                       FROM ifsdmclntpf
                      WHERE clntnum = rw_acct.cownnum;
                     IF lv_clttype = 'C'
                     THEN
                        lv_customer_type := 'COR';
                        lv_relationship := 'COR';
                     ELSE
                        lv_customer_type := 'IND';
                        lv_relationship := 'IND';
                     END IF;
                  ELSE
                     lv_customer_type := 'JOI';
                     SELECT DECODE (lv_dueflg,
                                    'A', 'AND',
                                    'J', 'JUV',
                                    'O', 'OR',
                                    ''
                                   )
                       INTO lv_auth_type
                       FROM IFSDMCHDRPF
                       where cownnum=rw_acct.cownnum
                       and rownum=1;
                  END IF;
                  -- create r_customer record
                  INSERT INTO r_customer
                              (entityid, customer_type,
                               auth_type, dt_created, created_by
                              )
                       VALUES (seq_r_customer.NEXTVAL, lv_customer_type,
                               lv_auth_type, SYSDATE, 'EOD-NEWFE'
                              );
                  SELECT seq_r_customer.CURRVAL
                    INTO lv_entity_id
                    FROM DUAL;
/* IND,JOI,COR */
              -- insert r_custuser_matrix for COWNNUM
                  INSERT INTO r_custuser_matrix
                              (entity_id, relationship,
                               user_info_id
                              )
                       VALUES (lv_entity_id, 'JO1',
                               (SELECT MAX (user_info_id)
                                  FROM r_user_info
                                 WHERE clntnum = rw_acct.cownnum)
                              );
                  -- insert r_custuser_matrix for JOWNNUM
                  IF rw_acct.jownnum != '        '
                  THEN
                     INSERT INTO r_custuser_matrix
                                 (entity_id, relationship,
                                  user_info_id
                                 )
                          VALUES (lv_entity_id, 'JO2',
                                  (SELECT MAX (user_info_id)
                                     FROM r_user_info
                                    WHERE clntnum = rw_acct.jownnum)
                                 );
                  END IF;
                  -- insert into audit trail
                  v_table_nm := ',R_CUSTOMER,R_CUSTUSER_MATRIX';
                  v_after :=
                        '|'
                     || TO_CHAR (lv_entity_id)
                     || '|'
                     || TO_CHAR (rw_acct.cownnum)
                     || '|'
                     || TO_CHAR (rw_acct.jownnum);
                  insertauditlog (v_action, v_table_nm, v_before, v_after);
               END IF;
               -- Ensure there's no duplicate
               SELECT COUNT (*)
                 INTO lv_plan_acct
                 FROM plan_acct
                WHERE chdrcoy = rw_acct.chdrcoy
                  AND chdrnum = rw_acct.chdrnum;
                  --AND entity_id = lv_entity_id;
               IF lv_plan_acct = 0
               THEN
                  SELECT seq_plan_acct.NEXTVAL
                    INTO v_acctid
                    FROM DUAL;
                  -- insert into plan_acct
                  INSERT INTO plan_acct
                              (acctid, chdrcoy, chdrnum, status,
                               entity_id, dt_created, created_by
                              )
                       VALUES (v_acctid, rw_acct.chdrcoy, rw_acct.chdrnum, 'A',
                               lv_entity_id, SYSDATE, 'EOD-NEWFE'
                              );
                  -- insert into portfolio and update plan_acct if there is transaction from AOL, if not --> skip
                  select count(*)
                  into lv_eref
                  from trx_ut
                  inner join ifsdmutrnpf on trim(ifsdmutrnpf.ZTRANREF) = trim(trx_ut.E_REFERENCE_NUMBER)
                  inner join ifsdmchdrpf on ifsdmchdrpf.CHDRNUM = ifsdmutrnpf.CHDRNUM
                  and ifsdmchdrpf.CHDRCOY = ifsdmutrnpf.CHDRCOY
                  inner join plan_acct on plan_acct.CHDRNUM = ifsdmchdrpf.CHDRNUM
                  where plan_acct.ACCTID = v_acctid;
                  if lv_eref > 0 then
                    select e_reference_number into lv_e_ref_number
                    from trx_ut
                    inner join ifsdmutrnpf on trim(ifsdmutrnpf.ZTRANREF) = trim(trx_ut.E_REFERENCE_NUMBER)
                    inner join ifsdmchdrpf on ifsdmchdrpf.CHDRNUM = ifsdmutrnpf.CHDRNUM
                    and ifsdmchdrpf.CHDRCOY = ifsdmutrnpf.CHDRCOY
                    inner join plan_acct on plan_acct.CHDRNUM = ifsdmchdrpf.CHDRNUM
                    where plan_acct.ACCTID = v_acctid
                    group by e_reference_number;
                    insertportfolio(lv_e_ref_number);
                    updatebeneficialplanacct(lv_e_ref_number);
                  end if;
                  -- insert into audit trail
                  v_action := 'NEW_ACCT';
                  v_table_nm := 'PLAN_ACCT' || v_table_nm;
                  v_before := '';
                  v_after :=
                        TO_CHAR (v_acctid)
                     || '|'
                     || TO_CHAR (rw_acct.chdrcoy)
                     || '|'
                     || TO_CHAR (rw_acct.chdrnum)
                     || '|'
                     || TO_CHAR (lv_entity_id);
                  insertauditlog (v_action, v_table_nm, v_before, v_after);
               END IF;
            END IF;
         END IF;
         --lv_countcom := lv_countcom + 1;
         --if lv_countcom > 1000 then
         -- lv_countcom :=0;
         -- commit;
         --end if;
      END LOOP;
      --commit;
      CLOSE c_acct;
      OPEN c_portfolio (v_eod_date_acct);
      LOOP
         FETCH c_portfolio
          INTO r_erefnum;
         EXIT WHEN c_portfolio%NOTFOUND;
         insertportfolio(r_erefnum);
      END LOOP;
      CLOSE c_portfolio;
      inserteodlog ('NEW_ACCT', 'S');
      insertinvestoragent;
      --EODPROC.sendNotification(--enter notification parameters);
      --COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_agent%ISOPEN  THEN CLOSE c_agent ; END IF;
        IF c_user%ISOPEN  THEN CLOSE c_user ; END IF;
        IF c_acct%ISOPEN  THEN CLOSE c_acct ; END IF;
        IF c_portfolio%ISOPEN  THEN CLOSE c_portfolio ; END IF;
         inserteodlog ('NewCustomerRecord', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE genpwdforfrontendusers
   IS
      -- 4.8 Generate Password For Front End Users
      v_passwordresetdatelastrun   r_sysparam.VALUE%TYPE;
      lv_user_id                   r_user.user_id%TYPE;
      lv_login_id                  r_user.login_id%TYPE;
      lv_email                     ifsdmclntpf.zemailadd%TYPE;
      lv_pwd_regen_flag            r_user.pwd_regen_flag%TYPE;
      v_ctr                        NUMBER;
      lv_cltaddr01                 ifsdmclntpf.cltaddr01%TYPE;
      lv_cltaddr02                 ifsdmclntpf.cltaddr02%TYPE;
      lv_cltaddr03                 ifsdmclntpf.cltaddr03%TYPE;
      lv_cltaddr04                 ifsdmclntpf.cltaddr04%TYPE;
      lv_cltaddr05                 ifsdmclntpf.cltaddr05%TYPE;
      CURSOR c_user
      IS
         SELECT a.user_id, a.login_id, c.zemailadd, a.pwd_regen_flag,
                c.cltaddr01, c.cltaddr02, c.cltaddr03, c.cltaddr04,
                c.cltaddr05
                  FROM r_user a, r_user_info b, ifsdmclntpf c
                 WHERE a.user_id = b.user_id
                   AND b.clntnum = c.clntnum
            AND a.pwd_regen_flag = 'Y';
      v_email                      VARCHAR2 (20);
   BEGIN
      SELECT VALUE
        INTO v_passwordresetdatelastrun
        FROM r_sysparam
       WHERE param_code = 'PASSWORD_RESET_DATE_LAST_RUN';
      -- add effective date and status conditions if required
      OPEN c_user;
      LOOP
         FETCH c_user
          INTO lv_user_id, lv_login_id, lv_email, lv_pwd_regen_flag,
               lv_cltaddr01, lv_cltaddr02, lv_cltaddr03, lv_cltaddr04,
               lv_cltaddr05;
         EXIT WHEN c_user%NOTFOUND;
         SELECT COUNT (*)
           INTO v_ctr
           FROM r_user_process b
          WHERE b.user_id = lv_user_id;
         IF v_ctr = 0
         THEN
            requestpassword (lv_user_id,
                             lv_login_id,
                             lv_email,
                             lv_cltaddr01,
                             lv_cltaddr02,
                             lv_cltaddr03,
                             lv_cltaddr04,
                             lv_cltaddr05
                            );
         END IF;
         UPDATE r_user ru
            SET pwd_regen_flag = 'N'
          WHERE ru.user_id = lv_user_id;
         v_action := 'ResetPW';
         v_table_nm := 'R_USER';
         v_before := lv_user_id || '|' || lv_pwd_regen_flag;
         v_after := lv_user_id || '|' || 'N';
         insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_user;
      UPDATE r_sysparam
         SET VALUE = TO_NUMBER (TO_CHAR (SYSDATE, 'YYYYDDMM'))
       WHERE param_code = 'PASSWORD_RESET_DATE_LAST_RUN';
      inserteodlog ('GenPwdForFrontEnd', 'S');
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_user%ISOPEN  THEN CLOSE c_user ; END IF;
         inserteodlog ('GenPwdForFrontEnd', 'F', SQLERRM);
         -- COMMIT;
   END;
   PROCEDURE transactionnotification
   IS
      -- 4.9 Transaction Notification
      l_trx_ut_id    trx_ut.trx_ut_id%TYPE;
      l_trx_status   trx_ut.trx_status%TYPE;
      CURSOR c_trxapp
      IS
         SELECT trx_ut_id, trx_status
           FROM trx_ut a
          WHERE a.trx_status = 'ORD'
            AND NOT EXISTS (
                   SELECT 'X'
                     FROM ifsdmutrnpf b
                    WHERE a.reference_id = TRIM (b.ztranref)
                      AND b.fdbkind != 'Y');
   BEGIN
--dbms_output.put_line('Start EODPROC49');
      OPEN c_trxapp;
      LOOP
         FETCH c_trxapp
          INTO l_trx_ut_id, l_trx_status;
         EXIT WHEN c_trxapp%NOTFOUND;
--dbms_output.put_line('updating '||l_trx_ut_id);
         UPDATE trx_ut
            SET trx_status = 'SUC'                           -- set to SUCCESS
          WHERE trx_ut_id = l_trx_ut_id;
-- generate PDF file and send to client
         v_action := 'TrxApp';
         v_table_nm := 'TRX_UT';
         v_before := l_trx_ut_id || '|' || l_trx_status;
         v_after := l_trx_ut_id || '|' || 'SUC';
         insertauditlog (v_action, v_table_nm, v_before, v_after);
      END LOOP;
      CLOSE c_trxapp;
--dbms_output.put_line('End EODPROC49');
      inserteodlog ('TransactionApproval', 'S');
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_trxapp%ISOPEN  THEN CLOSE c_trxapp ; END IF;
         inserteodlog ('TransactionApproval', 'F', SQLERRM);
         -- COMMIT;
   END;
   PROCEDURE massemailannualreport
   IS
      -- 4.11 Mass Email Annual Report
      lv_to               VARCHAR2 (4000);
      lv_mail_temp        mail_temp%ROWTYPE;
      lv_user_id          r_user_info.user_id%TYPE;
      CURSOR c_mail_temp
      IS
         SELECT *
           FROM mail_temp
          WHERE status = 'PND';
      lv_mail_temp_file   mail_temp_file%ROWTYPE;
      CURSOR c_mail_temp_file (p_mail_temp_id mail_temp.mail_temp_id%TYPE)
      IS
         SELECT *
           FROM mail_temp_file
          WHERE mail_temp_id = p_mail_temp_id;
      lv_mail_temp_rcpt   mail_temp_rcpt%ROWTYPE;
      CURSOR c_mail_temp_rcpt (p_mail_temp_id mail_temp.mail_temp_id%TYPE)
      IS
         SELECT *
           FROM mail_temp_rcpt
          WHERE mail_temp_id = p_mail_temp_id;
   BEGIN
      OPEN c_mail_temp;
      LOOP
         FETCH c_mail_temp
          INTO lv_mail_temp;
         EXIT WHEN c_mail_temp%NOTFOUND;
         OPEN c_mail_temp_rcpt (lv_mail_temp.mail_temp_id);
         LOOP
            FETCH c_mail_temp_rcpt
             INTO lv_mail_temp_rcpt;
            EXIT WHEN c_mail_temp_rcpt%NOTFOUND;
            SELECT DECODE (race,
                           'CHI', (TRIM (surname) || ' ' || TRIM (givname)),
                           (TRIM (givname) || ' ' || TRIM (surname)
                           )
                          )
              INTO lv_to
              FROM ifsdmclntpf
             WHERE clntnum = lv_mail_temp_rcpt.clntnum AND ROWNUM < 2;
            SELECT user_id
              INTO lv_user_id
              FROM r_user_info
             WHERE clntnum = lv_mail_temp_rcpt.clntnum AND ROWNUM < 2;
            INSERT INTO mail
                        (mail_id, owner_id, "FROM",
                         "TO", MESSAGE, mail_type, subject,
                         dt_mail, created_by, dt_created,
                         STATUS, NEW_MAIL_FLAG
                        )
                 VALUES (seq_mail.NEXTVAL, lv_user_id,
                                                       -- lv_mail_temp_rcpt.user_id,
                         'SYSTEM',
                         lv_to, lv_mail_temp.MESSAGE, 'I', 'Fund Information',
                         SYSDATE, 'EOD-MASSMAILER', SYSDATE,'A','Y'
                        );
            OPEN c_mail_temp_file (lv_mail_temp.mail_temp_id);
            LOOP
               FETCH c_mail_temp_file
                INTO lv_mail_temp_file;
               EXIT WHEN c_mail_temp_file%NOTFOUND;
               INSERT INTO mail_dtl
                           (mail_id, attachment_id
                           )
                    VALUES (seq_mail.CURRVAL, lv_mail_temp_file.attachment_id
                           );
            END LOOP;
            CLOSE c_mail_temp_file;
         END LOOP;
         CLOSE c_mail_temp_rcpt;
         UPDATE mail_temp
            SET status = 'CMP'
          WHERE mail_temp_id = lv_mail_temp.mail_temp_id;
/*
        V_ACTION   := 'MailAnlRep';
        V_TABLE_NM := 'MAIL/MAIL_DTL';
        V_BEFORE   := '';
        V_AFTER    := l_trx_ut_id||'|'||'SUC';
        InsertAuditLog(V_ACTION, V_TABLE_NM, V_BEFORE, V_AFTER);
*/
      END LOOP;
      CLOSE c_mail_temp;
      inserteodlog ('AnnualReport', 'S');
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_mail_temp%ISOPEN  THEN CLOSE c_mail_temp ; END IF;
        IF c_mail_temp_file%ISOPEN  THEN CLOSE c_mail_temp_file ; END IF;
        IF c_mail_temp_rcpt%ISOPEN  THEN CLOSE c_mail_temp_rcpt ; END IF;
         inserteodlog ('AnnualReport', 'F', SQLERRM);
         -- COMMIT;
   END;
   PROCEDURE refreshexpnotes
   IS
      -- 4.12a Refresh Explanatory Notes
      /*
      create  index IFSDMT9065_IX01 on IFSDMT9065("ITEMPFX","ITEMCOY","ITEMITEM");
      create  index IFSDMT9065_IX02 on IFSDMT9065("ITEMITEM");
      create  index R_EXPLANATORY_NOTES_IX01 on R_EXPLANATORY_NOTES("NOTEITEM");
      create  index R_EXPLANATORY_NOTES_IX02 on R_EXPLANATORY_NOTES("CRTABLE","BILLFREQ","CHDRCOY")
      */
      lv_componentcode        ifsdmcovrpf.crtable%TYPE;
      lv_paymentfrequency     VARCHAR2 (8);
      lv_chdrcoy              VARCHAR2 (1);
      lv_search_string        VARCHAR2 (255);
      lv_single_premium_ind   VARCHAR2 (255);
      lv_noteitem             ifsdmt9065.longdesc%TYPE;
      lv_notedesc             ifsdmt9065.trandesc%TYPE;
      lv_ctr                  NUMBER;
      CURSOR c_main
      IS
         SELECT a.crtable componentcode,
                         RTRIM (b.itemitem) paymentfrequency,
                         c.chdrcoy companycode
                    FROM (SELECT crtable
                                     FROM ifsdmcovrpf
                                    WHERE chdrcoy IN ('1', '2', '3', '7')
                                      AND validflag = '1'
                                      AND coverage = '01'
                                      AND rider = '00'
                          group by crtable
                          UNION
                          SELECT crtable
                                     FROM ifsdmcovtpf
                                    WHERE chdrcoy IN ('1', '2', '3', '7')
                                      AND coverage = '01'
                                      AND rider = '00'
                          group by crtable) a,
                         ifsdmt3590 b,
                         (SELECT '1' chdrcoy
                                    FROM DUAL
                                  UNION ALL
                                  SELECT '2' chdrcoy
                                    FROM DUAL
                                  UNION ALL
                                  SELECT '3' chdrcoy
                                    FROM DUAL) c
                    group by a.crtable,
                         b.itemitem,
                         c.chdrcoy ;
   BEGIN
      OPEN c_main;
      LOOP
         FETCH c_main
          INTO lv_componentcode, lv_paymentfrequency, lv_chdrcoy;
         EXIT WHEN c_main%NOTFOUND;
         SELECT COUNT (*)
           INTO lv_ctr
           FROM ifsdmt5687
          WHERE itemcoy = lv_chdrcoy
            AND itemitem = RPAD (lv_componentcode, 8, ' ')
            AND itmto = '99999999';
         lv_single_premium_ind := '-';
         IF lv_ctr = 1
         THEN
            SELECT sp_ind
              INTO lv_single_premium_ind
              FROM ifsdmt5687
             WHERE itemcoy = lv_chdrcoy
               AND itemitem = RPAD (lv_componentcode, 8, ' ')
               AND itmto = '99999999';
         END IF;
         lv_ctr := 0;
         lv_search_string :=
                   'EX' || lv_paymentfrequency || lv_single_premium_ind || '%';
         SELECT COUNT (*)
           INTO lv_ctr
           FROM ifsdmt9065
          WHERE itempfx = 'IT'
            AND itemcoy IN ('1', '2', '3', '7')
            AND itemitem LIKE lv_search_string;
         IF lv_ctr = 0
         THEN
            lv_search_string := 'EX**' || lv_single_premium_ind || '%';
         END IF;
         MERGE INTO r_explanatory_notes a
            USING (SELECT longdesc, trandesc
                     FROM ifsdmt9065
                    WHERE itempfx = 'IT'
                      AND itemcoy IN ('1', '2', '3', '7')
                      AND itemitem LIKE lv_search_string) b
            ON (a.chdrcoy = lv_chdrcoy
            AND a.billfreq = lv_paymentfrequency
            AND a.crtable = lv_componentcode
            AND a.noteitem = TRIM (b.longdesc))
            WHEN MATCHED THEN
               UPDATE
                  SET a.notedesc = b.trandesc
            WHEN NOT MATCHED THEN
               INSERT (chdrcoy, billfreq, crtable, noteitem, notedesc)
               VALUES (lv_chdrcoy, lv_paymentfrequency, lv_componentcode,
                       TRIM (b.longdesc), TRIM (b.trandesc));
      END LOOP;
      CLOSE c_main;
/*
        V_ACTION   := 'MailAnlRep';
        V_TABLE_NM := 'MAIL/MAIL_DTL';
        V_BEFORE   := '';
        V_AFTER    := l_trx_ut_id||'|'||'SUC';
        InsertAuditLog(V_ACTION, V_TABLE_NM, V_BEFORE, V_AFTER);
*/
      inserteodlog ('RefreshExpNotes', 'S');
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_main%ISOPEN  THEN CLOSE c_main ; END IF;
         inserteodlog ('RefreshExpNotes', 'F', SQLERRM);
         -- COMMIT;
   END;
   PROCEDURE refreshtrxdescription
   IS
      -- 4.12b Refresh Transaction Description
      descriptionfound   VARCHAR2 (10);
      searchstring1      VARCHAR2 (255);
      searchstring2      VARCHAR2 (255);
      searchstring3      VARCHAR2 (255);
      searchstring4      VARCHAR2 (255);
      searchstring5      VARCHAR2 (255);
      searchstring6      VARCHAR2 (255);
      lv_ctr             NUMBER;
      lv_acc_type        ifsdmchdrpf.cnttype%TYPE;
      lv_unit_type       ifsdmlzubpf.unityp%TYPE;
      lv_batch_num       ifsdmutrnpf.batctrcde%TYPE;
      lv_sub_acc_type    ifsdmutrnpf.sacstyp%TYPE;
      lv_transdesc       r_trx_description.trandesc%TYPE;
      cv_search1         ifsdmt9065%ROWTYPE;
      cv_search2         ifsdmt9065%ROWTYPE;
      cv_search3         ifsdmt9065%ROWTYPE;
      cv_last            ifsdmt1688%ROWTYPE;
      TYPE tran_var IS TABLE OF VARCHAR2 (255)
         INDEX BY PLS_INTEGER;
      trandesc           tran_var;
      CURSOR c_main
      IS
         SELECT DISTINCT a.cnttype acc_type, b.unityp unit_type,
                         c.batctrcde batch_num, c.sacstyp sub_acc_type
                    FROM ifsdmchdrpf a, ifsdmlzubpf b, ifsdmutrnpf c
                   WHERE b.chdrcoy = a.chdrcoy
                     AND b.chdrnum = a.chdrnum
                     AND c.chdrcoy = a.chdrcoy
                     AND c.chdrnum = a.chdrnum
                     AND c.vrtfnd = b.vrtfnd
         UNION
         SELECT DISTINCT a.cnttype acc_type, b.unityp unit_type,
                         b.batctrcde batch_num, b.sacstyp sub_acc_type
                    FROM ifsdmchdrpf a, ifsdmlzsdpf b
                   WHERE b.chdrcoy = a.chdrcoy AND b.chdrnum = a.chdrnum;
      CURSOR c_search1 (p_search_string VARCHAR2)
      IS
         SELECT *
           FROM ifsdmt9065
          WHERE itempfx = 'IT'
            AND itemcoy IN ('1', '2', '3', '7')
            AND itemitem LIKE p_search_string;
      CURSOR c_search2 (p_search_string VARCHAR2)
      IS
         SELECT *
           FROM ifsdmt9065
          WHERE itempfx = 'IT'
            AND itemcoy IN ('1', '2', '3', '7')
            AND itemitem LIKE p_search_string;
      CURSOR c_search3 (p_search_string VARCHAR2)
      IS
         SELECT *
           FROM ifsdmt9065
          WHERE itempfx = 'IT'
            AND itemcoy IN ('1', '2', '3', '7')
            AND itemitem LIKE p_search_string;
      CURSOR c_last (p_search_string VARCHAR2)
      IS
         SELECT *
           FROM ifsdmt1688
          WHERE itempfx = 'IT'
            AND itemcoy IN ('1', '2', '3', '7')
            AND itemitem LIKE p_search_string
            AND ROWNUM < 2;
   BEGIN
      OPEN c_main;
      LOOP
         FETCH c_main
          INTO lv_acc_type, lv_unit_type, lv_batch_num, lv_sub_acc_type;
         EXIT WHEN c_main%NOTFOUND;
         descriptionfound := 'FALSE';
         searchstring1 :=
                    '%' || lv_batch_num || lv_acc_type || lv_unit_type || '%';
         OPEN c_search1 (searchstring1);
         LOOP
            FETCH c_search1
             INTO cv_search1;
            EXIT WHEN c_search1%NOTFOUND;
            searchstring2 := '%' || lv_batch_num || lv_sub_acc_type || '%';
            FOR i IN 1 .. 6
            LOOP
               trandesc (i) :=
                            SUBSTR (cv_search1.trandesc, 78 * (i - 1) + 1,
                                    78);
               IF INSTR (trandesc (i), searchstring2) > 0
               THEN
                  searchstring3 := '%' || SUBSTR (trandesc (i), 1, 8) || '%';
                  OPEN c_search3 (searchstring3);
                  LOOP
                     FETCH c_search3
                      INTO cv_search3;
                     EXIT WHEN c_search3%NOTFOUND;
                     lv_transdesc := cv_search3.trandesc;
                     descriptionfound := 'TRUE';
                     EXIT WHEN descriptionfound = 'TRUE';
                  END LOOP;
                  CLOSE c_search3;
               END IF;
               EXIT WHEN descriptionfound = 'TRUE';
            END LOOP;
         END LOOP;
         CLOSE c_search1;
         IF descriptionfound != 'TRUE'
         THEN
            searchstring2 :=
                '%' || lv_batch_num || lv_sub_acc_type || lv_unit_type || '%';
            OPEN c_search2 (searchstring2);
            LOOP
               FETCH c_search2
                INTO cv_search2;
               EXIT WHEN c_search2%NOTFOUND;
               lv_transdesc := cv_search2.trandesc;
               descriptionfound := 'TRUE';
            END LOOP;
            CLOSE c_search2;
         END IF;
         IF descriptionfound != 'TRUE'
         THEN
            searchstring4 :=
                            '%****' || lv_sub_acc_type || lv_unit_type || '%';
            OPEN c_search2 (searchstring4);
            LOOP
               FETCH c_search2
                INTO cv_search2;
               EXIT WHEN c_search2%NOTFOUND;
               lv_transdesc := cv_search2.trandesc;
               descriptionfound := 'TRUE';
            END LOOP;
            CLOSE c_search2;
         END IF;
         IF descriptionfound != 'TRUE'
         THEN
            searchstring5 := '%****' || lv_sub_acc_type || '%';
            OPEN c_search2 (searchstring5);
            LOOP
               FETCH c_search2
                INTO cv_search2;
               EXIT WHEN c_search2%NOTFOUND;
               lv_transdesc := cv_search2.trandesc;
               descriptionfound := 'TRUE';
            END LOOP;
            CLOSE c_search2;
         END IF;
         IF descriptionfound != 'TRUE'
         THEN
            searchstring6 := '%' || lv_batch_num || '%';
            OPEN c_last (searchstring6);
            LOOP
               FETCH c_last
                INTO cv_last;
               EXIT WHEN c_last%NOTFOUND;
               lv_transdesc := cv_last.longdesc;
               descriptionfound := 'TRUE';
            END LOOP;
            CLOSE c_last;
         END IF;
         MERGE INTO r_trx_description a
            USING (SELECT 'X'
                     FROM DUAL) b
            ON (a.cnttype = lv_acc_type
            AND a.unityp = lv_unit_type
            AND a.batctrcde = lv_batch_num
            AND a.sacstyp = lv_sub_acc_type)
            WHEN MATCHED THEN
               UPDATE
                  SET a.trandesc = TRIM (lv_transdesc)
            WHEN NOT MATCHED THEN
               INSERT (cnttype, unityp, batctrcde, sacstyp, trandesc)
               VALUES (lv_acc_type, lv_unit_type, lv_batch_num,
                       lv_sub_acc_type, TRIM (lv_transdesc));
      END LOOP;
      CLOSE c_main;
/*
        V_ACTION   := 'MailAnlRep';
        V_TABLE_NM := 'MAIL/MAIL_DTL';
        V_BEFORE   := '';
        V_AFTER    := l_trx_ut_id||'|'||'SUC';
        InsertAuditLog(V_ACTION, V_TABLE_NM, V_BEFORE, V_AFTER);
*/
      inserteodlog ('TrxDescription', 'S');
      -- COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
        IF c_main%ISOPEN  THEN CLOSE c_main ; END IF;
        IF c_search1%ISOPEN  THEN CLOSE c_search1 ; END IF;
        IF c_search2%ISOPEN  THEN CLOSE c_search2 ; END IF;
        IF c_search3%ISOPEN  THEN CLOSE c_search3 ; END IF;
        IF c_last%ISOPEN  THEN CLOSE c_last ; END IF;
         inserteodlog ('TrxDescription', 'F', SQLERRM);
         -- COMMIT;
   END;

   PROCEDURE inserteodlog (p_eodname IN VARCHAR2, p_status IN VARCHAR2)
   IS
   BEGIN
      INSERT INTO EOD_LOG
                  (eod_proc_name, eod_date, status, dt_created, created_by
                  )
           VALUES (p_eodname, SYSDATE, p_status, SYSDATE, 'EOD_PROCESS'
                  );
   END;

   PROCEDURE inserteodlog (
      p_eodname   IN   VARCHAR2,
      p_status    IN   VARCHAR2,
      p_error     IN   VARCHAR2
   )
   IS
/*
alter table eod_log add
(remarks varchar2(4000));
*/
   BEGIN
      INSERT INTO eod_log
                  (eod_proc_name, eod_date, status, dt_created, created_by,
                   remarks
                  )
           VALUES (p_eodname, SYSDATE, p_status, SYSDATE, 'EOD_PROCESS',
                   p_error
                  );
   END;
   PROCEDURE insertauditlog (
      p_action   IN   VARCHAR2,
      p_table    IN   VARCHAR2,
      p_before   IN   VARCHAR2,
      p_after    IN   VARCHAR2
   )
   IS
   BEGIN
      INSERT INTO audit_trail
                  (audit_id, action, table_nm, dt_created,
                   created_by, audit_type, data1, data2
                  )
           VALUES (seq_audit_trail.NEXTVAL, p_action, p_table, SYSDATE,
                   'EOD_PROCESS', 'E', p_before, p_after
                  );
   END;
   PROCEDURE sendnotification
   IS
   BEGIN
      NULL;
   END;
   PROCEDURE requestpassword (
      p_user        IN   VARCHAR2,
      p_login       IN   VARCHAR2,
      p_email       IN   VARCHAR2,
      p_cltaddr01   IN   VARCHAR2,
      p_cltaddr02   IN   VARCHAR2,
      p_cltaddr03   IN   VARCHAR2,
      p_cltaddr04   IN   VARCHAR2,
      p_cltaddr05   IN   VARCHAR2
   )
   IS
   /* - ddl for R_USER_PROCESS
     CREATE TABLE R_USER_PROCESS (
       USER_ID   VARCHAR2(50),
       LOGIN_ID  VARCHAR2(50),
       EMAIL     VARCHAR2(50),
       GENPASS   VARCHAR2(100),
       cltaddr01 varchar2(30),
       cltaddr02 varchar2(30),
       cltaddr03 varchar2(30),
       cltaddr04 varchar2(30),
       cltaddr05 varchar2(30));
   */
   BEGIN
      INSERT INTO r_user_process
                  (user_id, login_id, email, cltaddr01, cltaddr02,
                   cltaddr03, cltaddr04, cltaddr05
                  )
           VALUES (p_user, p_login, p_email, p_cltaddr01, p_cltaddr02,
                   p_cltaddr03, p_cltaddr04, p_cltaddr05
                  );
      -- COMMIT;
   END;
   FUNCTION get_entity (p_cownnum VARCHAR2, p_jownnum VARCHAR2)
      RETURN NUMBER
   IS
      -- returns entityid. if not found, returns -999
      v_entity_id   r_custuser_matrix.entity_id%TYPE;
      v_jownnum     ifsdmchdrpf.jownnum%TYPE;
   BEGIN
      v_jownnum := NVL (p_jownnum, '        ');
      IF v_jownnum = '        '
      THEN
         SELECT max(a.entity_id)
           INTO v_entity_id
           FROM r_custuser_matrix a, r_user_info b
          WHERE a.user_info_id = b.user_info_id
            AND b.clntnum = p_cownnum
            AND a.entity_id NOT IN (
                   SELECT u.entity_id
                     FROM r_custuser_matrix u, r_user_info v
                    WHERE u.user_info_id = v.user_info_id
                      AND u.entity_id = a.entity_id
                      AND v.clntnum != p_cownnum);
      ELSE
         SELECT max(w.entity_id)
           INTO v_entity_id
           FROM r_custuser_matrix w, r_user_info x
          WHERE w.user_info_id = x.user_info_id
            and w.RELATIONSHIP = 'JO1'
            AND x.clntnum = p_cownnum
            AND w.entity_id IN (
                   SELECT MAX (m.entity_id)
                     FROM r_custuser_matrix m, r_user_info n
                    WHERE m.user_info_id = n.user_info_id
                      AND m.entity_id = w.entity_id
                      and m.RELATIONSHIP = 'JO2'
                      AND n.clntnum = v_jownnum);
      END IF;
      v_entity_id := NVL(v_entity_id, -999);
      RETURN v_entity_id;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN -999;
      WHEN OTHERS
      THEN
         RAISE;
   END;
 PROCEDURE RefreshUserAndPlanAcct
 IS
        lv_userid    r_user_info.user_id%TYPE;
        dummy        date;
        v_ctr        NUMBER;
        v_eod_refresh_planact  eod_log.eod_date%TYPE;
 BEGIN
       select sysdate into dummy from dual;
        SELECT COUNT (*)
          INTO v_ctr
          FROM eod_log
             WHERE eod_proc_name = 'REFRESH PLANACCT' AND status = 'S';
        IF v_ctr > 0
        THEN
           SELECT MAX (eod_date) - 5
             INTO v_eod_refresh_planact
             FROM eod_log
            WHERE eod_proc_name = 'REFRESH PLANACCT' AND status = 'S';
        ELSE
           v_eod_refresh_planact := TO_DATE ('01-JAN-1990', 'DD-MON-YY');
        END IF;
  -- Set plan account of customer who close the account/contract
  -- updated IE to set it to inactive if the contract is not in active state.
    UPDATE plan_acct
       SET status = 'I',
           dt_updated = SYSDATE,
           updated_by = 'REFRESH PLANACCT A'
     WHERE chdrnum IN (
              SELECT a.chdrnum
                FROM ifsdmchdrpf a
               WHERE a.statcode NOT IN ('AC', 'IF')
                 AND a.modidate >
                           TO_NUMBER (TO_CHAR (v_eod_refresh_planact, 'yyyymmdd'))
                       );
  -- update plan account if the plan account is marked as inactive in our plan_acct table
  -- but somehow the plan account is active in ifsdmchdrpf
    UPDATE plan_acct p
       SET p.status = 'A',
           p.dt_updated = SYSDATE,
           updated_by = 'REFRESH PLANACCT B'
     WHERE p.chdrnum IN (
              SELECT c.chdrnum
                FROM plan_acct p, ifsdmchdrpf c
               WHERE p.chdrnum = c.chdrnum
                 AND p.chdrcoy = c.chdrcoy
                 AND p.status = 'I'
                 AND c.chdrcoy in ('2','3')
                 AND c.statcode IN ('AC', 'IF'));
  -- Set user login to "I" when the plan account is inacative ("I")
  --for sel in c_inactiveacctuser
  --loop
--    update r_user set
      --UPDATED_BY = 'EODPROC48',
      --DT_UPDATED = sysdate,
      --status='I' where r_user.user_id=sel.user_id;
  --end loop;
  inserteodlog ('REFRESH PLANACCT', 'S');
  -- COMMIT;
  EXCEPTION
  WHEN OTHERS
  THEN
  inserteodlog ('REFRESH PLANACCT', 'F', SQLERRM);
   -- COMMIT;
 END;
 PROCEDURE insertportfolio(e_ref_number in varchar2)
   IS
      lv_account_id       plan_acct.acctid%TYPE;
      lv_portfolio_id     portfolio.portfolio_id%TYPE;
   BEGIN
      -- insert into portfolio from tmp_portfolio
      INSERT INTO PORTFOLIO
            ( PORTFOLIO_ID, RISK_CATEGORY_NM, EXP_RETURN, DT_CREATED, CREATED_BY,
            UPDATED_BY, DT_UPDATED, STATUS, ACCT_ID, PORTFOLIO_MODEL_ID,
            PORTFOLIO_BUILDER_TYPE )
      SELECT a.PORTFOLIO_ID, a.RISK_CATEGORY_NM, a.EXP_RETURN, SYSDATE, 'EOD-NEWFE',
            'EOD-NEWFE', SYSDATE, a.STATUS, plan_acct.acctid, a.PORTFOLIO_MODEL_ID,
            a.PORTFOLIO_BUILDER_TYPE
            from tmp_portfolio a
   inner join trx_ut on trx_ut.ACCOUNT_ID = a.ACCOUNT_TEMP_ID
            and trim(trx_ut.E_REFERENCE_NUMBER) = e_ref_number
   inner join ifsdmutrnpf on trim(trx_ut.E_REFERENCE_NUMBER) = trim(ifsdmutrnpf.ZTRANREF)
   inner join ifsdmchdrpf on ifsdmutrnpf.CHDRNUM = ifsdmchdrpf.CHDRNUM
        and ifsdmutrnpf.CHDRCOY = ifsdmchdrpf.CHDRCOY
   inner join plan_acct on ifsdmchdrpf.CHDRNUM = plan_acct.CHDRNUM
   group by a.PORTFOLIO_ID, a.RISK_CATEGORY_NM, a.EXP_RETURN, a.DT_CREATED, a.CREATED_BY,
            a.UPDATED_BY, a.DT_UPDATED, a.STATUS, plan_acct.acctid, a.PORTFOLIO_MODEL_ID,
            a.PORTFOLIO_BUILDER_TYPE;
      --insert into portfolio_target
      INSERT INTO PORTFOLIO_TARGET
            ( AA_CLASS_ID, PORTFOLIO_ID, PERCENTAGE )
      SELECT a.AA_CLASS_ID, a.PORTFOLIO_ID, a.PERCENTAGE
            from TMP_PORTFOLIO_TARGET a
   inner join tmp_portfolio on tmp_portfolio.PORTFOLIO_ID = a.PORTFOLIO_ID
   inner join trx_ut on trx_ut.ACCOUNT_ID = tmp_portfolio.ACCOUNT_TEMP_ID
   and trx_ut.E_REFERENCE_NUMBER = e_ref_number;
      EXCEPTION
      WHEN OTHERS
      THEN
         inserteodlog ('insertportfolio', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE updatebeneficialplanacct (e_ref_number in varchar2)
   IS
      lv_beneficial_name              tmp_account.BENEFICIAL_NAME%TYPE;
      lv_beneficial_name_2            tmp_account.BENEFICIAL_NAME_2%TYPE;
      lv_beneficial_nric              tmp_account.BENEFICIAL_NRIC%TYPE;
      lv_beneficial_nric_2            tmp_account.BENEFICIAL_NRIC_2%TYPE;
      lv_beneficial_relationship      tmp_account.BENEFICIAL_RELATIONSHIP%TYPE;
      lv_beneficial_relationship_2    tmp_account.BENEFICIAL_RELATIONSHIP_2%TYPE;
      lv_branch_name                  tmp_account.BRANCH_NAME%TYPE;
      CURSOR beneficialtempaccount (e_ref_number in varchar2)
      IS
         SELECT beneficial_name, beneficial_name_2, beneficial_nric, beneficial_nric_2, beneficial_relationship, beneficial_relationship_2, branch_name
         from tmp_account
         inner join trx_ut on trx_ut.ACCOUNT_ID = tmp_account.ACCOUNT_TEMP_ID
         and trx_ut.E_REFERENCE_NUMBER = e_ref_number;
   BEGIN
      OPEN beneficialtempaccount (e_ref_number);
       LOOP
         FETCH beneficialtempaccount
          INTO
          lv_beneficial_name,
          lv_beneficial_name_2,
          lv_beneficial_nric,
          lv_beneficial_nric_2,
          lv_beneficial_relationship,
          lv_beneficial_relationship_2,
          lv_branch_name;
         EXIT WHEN beneficialtempaccount%NOTFOUND;
         UPDATE plan_acct
            SET
            beneficial_name = lv_beneficial_name,
            beneficial_name_2 = lv_beneficial_name_2,
            beneficial_nric = lv_beneficial_nric,
            beneficial_nric_2 = lv_beneficial_nric_2,
            beneficial_relationship = lv_beneficial_relationship,
            beneficial_relationship_2 = lv_beneficial_relationship_2,
            branch_name = lv_branch_name,
            DT_UPDATED = SYSDATE,
            UPDATED_BY = 'EOD-NEWFE'
          WHERE plan_acct.acctid = (
          SELECT a.ACCTID FROM PLAN_ACCT a
            INNER JOIN IFSDMCHDRPF ON IFSDMCHDRPF.CHDRNUM = a.CHDRNUM
            INNER JOIN IFSDMUTRNPF ON IFSDMUTRNPF.CHDRNUM = IFSDMCHDRPF.CHDRNUM
            AND IFSDMUTRNPF.CHDRCOY = IFSDMCHDRPF.CHDRCOY
            INNER JOIN TRX_UT ON trim(TRX_UT.E_REFERENCE_NUMBER) = trim(IFSDMUTRNPF.ZTRANREF)
            and TRX_UT.E_REFERENCE_NUMBER = e_ref_number
            group by a.ACCTID);
          END LOOP;
      CLOSE beneficialtempaccount;
      EXCEPTION
      WHEN OTHERS
      THEN
        IF beneficialtempaccount%ISOPEN  THEN CLOSE beneficialtempaccount ; END IF;
         inserteodlog ('updatebeneficialplanacct', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   PROCEDURE insertinvestoragent
   IS
      lv_r_user_info_user_id  r_user_info.user_id%TYPE;
      -- investor agent
      CURSOR c_investor_agent
      IS
         select user_id from(
          select r_user_info.user_id
          from ifsdmchdrpf
          inner join r_user_info on r_user_info.clntnum = ifsdmchdrpf.COWNNUM
          where
          ifsdmchdrpf.VALIDFLAG = '1' AND ifsdmchdrpf.STATCODE IN ('AC', 'IF')
          and not exists
          (select 1 from r_user_role where r_user_role.user_id = r_user_info.user_id)
          union
          select r_user_info.user_id
          from ifsdmchdrpf
          inner join r_user_info on r_user_info.clntnum = ifsdmchdrpf.JOWNNUM
          where
          ifsdmchdrpf.VALIDFLAG = '1' AND ifsdmchdrpf.STATCODE IN ('AC', 'IF')
          and not exists
          (select 1 from r_user_role where r_user_role.user_id = r_user_info.user_id)
          ) a group by user_id;
   BEGIN
   OPEN c_investor_agent;
      LOOP
         FETCH c_investor_agent
          INTO lv_r_user_info_user_id;
          EXIT WHEN c_investor_agent%NOTFOUND;
          INSERT INTO R_USER_ROLE (USER_ID, ROLE_ID, USER_ROLE_ID, DT_CREATED, CREATED_BY, UPDATED_BY,
                      DT_UPDATED, STATUS)
          VALUES
          (lv_r_user_info_user_id,
          (SELECT role_id
                         FROM r_role
                        WHERE role_nm = 'INVESTOR'),
          seq_r_user_role.NEXTVAL,
          SYSDATE,
          'EOD-NEWFE',
          'EOD-NEWFE',
          SYSDATE,
          'A');
      END LOOP;
      CLOSE c_investor_agent;
    EXCEPTION
      WHEN OTHERS
      THEN
        IF c_investor_agent%ISOPEN  THEN CLOSE c_investor_agent ; END IF;
         inserteodlog ('insertinvestoragent', 'F', SQLERRM);
         --EODPROC.sendNotification(--enter notification parameters);
         --raise;
         -- COMMIT;
   END;
   ----------------------------------- v2.9 added -------------------------------------- 
   PROCEDURE refreshuser
   IS
      lv_userid           r_user_info.user_id%TYPE;
      dummy               DATE;
      v_ctr               NUMBER;
      v_ctr_served_chdr   NUMBER;
      v_ctr_owned_chdr    NUMBER;
      v_ctr_active_agnt   NUMBER;
      v_cur_status                R_USER.status%TYPE;
      lv_user_id          R_USER_INFO.user_id%TYPE;
      lv_agntcoy         IFSDMAGLFPF.AGNTCOY%TYPE;
      v_eod_refresh_user  EOD_LOG.eod_date%TYPE;

--- modified by IE 28 nov 2008.
--- the query below will give the list of the user that has exactly 2 role (ADVISOR and INVESTOR)
--- it modify the original flow originally where it already check for active contract.
      CURSOR c_invtr_and_advr
      IS
         -- make sure user is user role=advisor and investor
                SELECT DISTINCT vur.user_id
                           FROM v_userrole vur, r_role rl, r_user_info i, ifsdmclntpf cl
                          WHERE vur.role_id = rl.role_id
                            AND i.user_id = vur.user_id
                            AND i.user_type = 'E'
                            AND rl.role_type IN ('V', 'I')
                            AND i.clntnum = cl.clntnum
                            AND cl.cltmchg = 'Y'
                       GROUP BY vur.user_id
                         HAVING COUNT (vur.role_id) = 2
                MINUS
                SELECT   vur.user_id
                    FROM v_userrole vur, r_role rl, r_user_info i, ifsdmclntpf cl
                   WHERE vur.role_id = rl.role_id
                     AND i.user_id = vur.user_id
                     AND i.user_type = 'E'
                     AND i.clntnum = cl.clntnum
                     AND cl.cltmchg = 'Y'
                GROUP BY vur.user_id
                  HAVING COUNT (vur.role_id) > 2;
        -- end IE to get the list of exactly advisor AND investor
        -- cursor to get the list of user that has additional role other than advisor/investor
        -- minus the user that have another agent number that may still be active
        -- (the user may have more than 1 agent number; and one of them may still be active)
        CURSOR c_others (p_eod_date_refUser IN DATE)
         IS        
             SELECT      /*+ index (r_user_info R_USER_INFO_IDX2) 
                                   index (r_agt_cl_role_map R_AGT_CL_ROLE_MAP_X1) */
                   DISTINCT i.user_id
                       FROM r_role rl,
                            r_user_info i,
                            ifsdmaglfpf aglf,
                            r_agt_cl_role_map MAP,
                            ifsdmclntpf c,
                            r_user u
                      WHERE aglf.clntnum = i.clntnum
                        AND aglf.zlfagtcl = MAP.zlfagtcl
                        AND i.user_type = 'E'
                        AND rl.role_id = MAP.role_id
                        AND (rl.role_type <> 'I' AND rl.role_type <> 'V')
                        AND c.clntnum = aglf.clntnum
                        AND u.user_id = i.user_id
                        AND c.cltmchg = 'Y'
                        -- AND c.modidate >= TO_NUMBER (TO_CHAR (p_eod_date_refUser, 'yyyymmdd'))
                        AND aglf.dtetrm <= TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmdd'))
                        -- AND aglf.modidate >= TO_NUMBER (TO_CHAR (p_eod_date_refUser, 'yyyymmdd'))
                        AND u.status = 'A'
             MINUS
             SELECT /*+ index (r_user_info R_USER_INFO_IDX2) 
                       index (r_agt_cl_role_map R_AGT_CL_ROLE_MAP_X1) */
                   i.user_id
              FROM r_role rl,
                   r_user_info i,
                   ifsdmaglfpf aglf,
                   r_agt_cl_role_map MAP,
                   ifsdmclntpf c,
                   r_user u
             WHERE aglf.clntnum = i.clntnum
               AND aglf.zlfagtcl = MAP.zlfagtcl
               AND i.user_type = 'E'
               AND rl.role_id = MAP.role_id
               AND c.clntnum = aglf.clntnum
               AND u.user_id = i.user_id
               AND c.cltmchg = 'Y'
               AND aglf.dtetrm > TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmdd'))
               AND aglf.agntcoy in ('2','3');
        -- cursor to get the list of ADVISOR ONLY.  
        -- The list get the list of user that has ADVISOR and remove the user that has role other than ADVISOR
        -- it also remove the user that also has the investor role (MINUS from r_user_role)
        CURSOR c_advr(p_eod_date_refUser IN DATE)
        IS
            SELECT U.USER_ID, AGLF.AGNTCOY
            FROM
            R_USER U
            INNER JOIN R_USER_INFO RUI ON RUI.USER_ID = u.user_id
            INNER JOIN IFSDMAGLFPF AGLF ON AGLF.CLNTNUM = RUI.CLNTNUM
            AND AGLF.agntcoy IN ('2', '3')
            AND AGLF.DTETRM >= TO_NUMBER (TO_CHAR(SYSDATE, 'yyyymmdd'))
            and u.user_id in 
            (
             SELECT  /*+ index (r_user_info R_USER_INFO_IDX2) 
                           index (r_agt_cl_role_map R_AGT_CL_ROLE_MAP_X1) */
                       i.user_id
                  FROM r_role rl, r_user_info i, ifsdmaglfpf ag, r_agt_cl_role_map MAP, ifsdmclntpf c
                 WHERE MAP.role_id = rl.role_id
                   AND ag.clntnum = i.clntnum
                   AND ag.zlfagtcl = MAP.zlfagtcl
                   AND i.user_type = 'E'
                   AND i.clntnum = c.clntnum
                   AND c.cltmchg = 'Y'
                   AND rl.role_type = 'V'
                   and ag.agntcoy in ('2', '3')
                   AND ag.dtetrm >= TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmdd'))
                   -- AND ag.modidate >= TO_NUMBER (TO_CHAR (p_eod_date_refUser, 'yyyymmdd'))
              MINUS
                SELECT /*+ index (r_user_info R_USER_INFO_IDX2) 
                           index (r_agt_cl_role_map R_AGT_CL_ROLE_MAP_X1) */
                       i.user_id
                  FROM r_role rl, r_user_info i, ifsdmaglfpf ag, r_agt_cl_role_map MAP
                 WHERE MAP.role_id = rl.role_id
                   AND ag.clntnum = i.clntnum
                   AND ag.zlfagtcl = MAP.zlfagtcl
                   AND i.user_type = 'E'
                   AND rl.role_type <> 'V'
                   AND ag.dtetrm >= TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmdd'))
                MINUS
                SELECT user_id
                  FROM r_user_role);
        -- cursor to get the list of INVESTOR ONLY.  
        -- The list get the list of user that has INVESTOR and remove the user that has role other than INVESTOR
      CURSOR c_inv (p_eod_date_refUser IN DATE)
      IS
                 SELECT i.user_id
                  FROM r_user_role r, r_user_info i, ifsdmclntpf c
                 WHERE i.user_id = r.user_id
                   AND i.user_type = 'E'
                   AND i.clntnum = c.clntnum
                   AND c.cltmchg = 'Y'
                   -- AND c.modidate >= TO_NUMBER (TO_CHAR (p_eod_date_refUser, 'yyyymmdd'))
                MINUS
                SELECT vur.user_id
                  FROM v_userrole vur, r_role rl, r_user_info i
                 WHERE vur.role_id = rl.role_id
                   AND i.user_id = vur.user_id
                   AND i.user_type = 'E'
                   AND rl.role_type <> 'I';
   BEGIN
             -- 1.  Get the date to run from 
             -- 2.  Start with the simpler user to handle:  
             --         a.  For all user where the WEB ENABLE flag is N set the user to inactive.
             --         b.  For those user that does have MANAGER  OR  DEALER  role
             --             i)  if the DTETRM > today  AND  status = 'I', then set to 'A' and set the RESET PASSWORD FLAG to Y
             --             ii) (need cursor), for those that suppose to be set to Inactive, need to check wether the user has any other active
             --                 user
             --         c.  For the user having BOTH  ADVISOR  AND  INVESTOR, make sure that 
             --             -- check if the user has active contract owned (jointly/individually), if exists, set status = 'A'
                --             -- check if the user served any active contract for company 2/3 AND IFSDMAGLPF.DTETRM > todays, if exists set status = 'A'
                --             -- if NONE exists, set status = 'I'
                --     d.  For user having ONLY ADVISOR
                --             -- check if the user served any active contract for company 2/3 AND IFSDMAGLPF.DTETRM > todays, if exists set status = 'A'
            --                 -- if NONE exists, set status = 'I' 
            --       e.  For user having only INVESTOR
             --             -- check if the user has active contract owned (jointly/individually), if exists, set status = 'A'
               --                  -- if NONE exists, set status = 'I'
               --         f.  Update EOD_LOG
             -- 
           -- 1. Get the date to run from.
           SELECT COUNT (*)
        INTO v_ctr
        FROM eod_log
       WHERE eod_proc_name = 'REFRESH USR' AND status = 'S';
      IF v_ctr > 0
      THEN
         SELECT MAX (eod_date) - 5
           INTO v_eod_refresh_user
           FROM eod_log
          WHERE eod_proc_name = 'REFRESH USR' AND status = 'S';
      ELSE
         v_eod_refresh_user := TO_DATE ('01-JAN-1990', 'DD-MON-YY');
      END IF;
      --- 1. end IE: added to get the date to run from
      /* 2a. All users whose web-enabled-flag='N' set to inactive */
      -- Set all the user where the flag for web enabled is set to N to became inactive regardless of their current status 
      -- 
      UPDATE r_user
         SET status = 'I',
             dt_updated = SYSDATE,
             r_user.updated_by = 'REFRESH USR 2A'
       WHERE user_id IN (  SELECT u.user_id
                           FROM r_user u
                            inner join r_user_info i on i.user_id = u.user_id
                            inner join ifsdmclntpf c on c.clntnum = i.clntnum
                            and c.cltmchg = 'N'
                           where u.status <>'I'
                                          );
            --- end updated by IE

      /* 2b. Users who have role other than Advisor and Investor and (IFSDMAGLFPF.DTETRM > todays) then
      set user status='A'*/
      --   i) if the DTETRM > today  AND  status = 'I', then set to 'A' and set the RESET PASSWORD FLAG to Y 
      UPDATE R_USER
               SET --status = 'A', commented by iman. status will be changed to R after reset password
                   dt_updated = SYSDATE,
                   R_USER.updated_by = 'REFRESH USR 2B',
                   R_USER.pwd_regen_flag = 'Y',
                   R_USER.DT_RESET_PASSWORD_UPDATED = SYSDATE
             WHERE user_id IN (
                      SELECT /*+ index (r_user_info R_USER_INFO_IDX2) 
                       index (r_agt_cl_role_map R_AGT_CL_ROLE_MAP_X1) */
                             i.user_id
                        FROM R_ROLE rl,
                             R_USER_INFO i,
                             IFSDMAGLFPF aglf,
                             R_AGT_CL_ROLE_MAP MAP,
                             IFSDMCLNTPF c,
                             R_USER u
                       WHERE aglf.clntnum = i.clntnum
                         AND aglf.zlfagtcl = MAP.zlfagtcl
                         AND i.user_type = 'E'
                         AND rl.role_id = MAP.role_id
                         AND (rl.role_type <> 'I' AND rl.role_type <> 'V')
                         AND c.clntnum = aglf.clntnum
                         AND u.user_id = i.user_id   
                         AND c.CLTMCHG = 'Y'      
                         AND aglf.dtetrm > TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmdd'))
                         AND u.status = 'I');

      /*2b.
          ii) Users who have role other than Advisor and Investor and (IFSDMAGLFPF.DTETRM < todays) then
       set user status='I' */
       -- The function will get the list of user where the web enable flag is Y, but the agent already terminated.
       -- However the agent may have multiple agent number and once of them may still be active
      Open c_others(v_eod_refresh_user);
      LOOP
         FETCH c_others
          INTO lv_user_id;
         EXIT WHEN c_others%NOTFOUND;                    
         -- need to check if the user is also an investor with active contract
         select count (distinct i.user_id )
           INTO v_ctr_owned_chdr
                 FROM R_USER_INFO i,
                      IFSDMCHDRPF ch
                WHERE i.user_id = lv_user_id
                     AND (i.clntnum = ch.cownnum OR i.clntnum = ch.jownnum)
                     AND ch.statcode IN ('AC', 'IF')
                     AND ch.chdrcoy in ('2','3');
         -- If above condition DOES NOT exists, then set it to INACTIVE
         IF (v_ctr_owned_chdr < 1) 
         THEN
                 -- set to inactive
            UPDATE r_user
               SET status = 'I', DT_UPDATED = SYSDATE, r_user.UPDATED_BY='REFRESH USR 2B-ii'
            WHERE user_id = lv_user_id; 
            END IF;
      END LOOP;
      /* 2c. user role = investor and advisor */
      OPEN c_invtr_and_advr;
      LOOP
         FETCH c_invtr_and_advr
          INTO lv_user_id;
         EXIT WHEN c_invtr_and_advr%NOTFOUND;
         --search served active-contract of the particular agent
         SELECT COUNT (DISTINCT ui.user_id)
           INTO v_ctr_served_chdr
           FROM IFSDMCHDRPF chdr, IFSDMAGLFPF ag, R_USER_INFO UI
          WHERE chdr.servagnt = ag.agntnum
            AND ag.DTETRM > TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmdd'))
            AND ag.clntnum = ui.clntnum
            AND chdr.chdrcoy IN (2, 3)
            AND chdr.statcode IN ('AC', 'IF')
            AND ui.user_id = lv_user_id;
         -- search the active contract owned by the user
         SELECT COUNT (DISTINCT i.user_id)
           INTO v_ctr_owned_chdr
                    FROM IFSDMCHDRPF ch, R_USER_INFO i
                   WHERE i.user_id = lv_user_id
                     AND (i.clntnum = ch.cownnum OR i.clntnum = ch.jownnum)
                     AND ch.statcode IN ('AC', 'IF')
                     AND ch.chdrcoy in ('2','3');
                  -- get the current status first.
                 SELECT u.status 
                 INTO v_cur_status
                 FROM R_USER u where u.user_id = lv_user_id;
         -- found the contract? yes!
         IF (v_ctr_served_chdr > 0) OR (v_ctr_owned_chdr > 0)
         THEN
                 -- it was inactive before, so need to reset the password as well.
                 IF (v_cur_status = 'I')
                 THEN
                -- set to active
                UPDATE r_user
                   SET -- status = 'A',
                       dt_updated = SYSDATE,
                               r_user.updated_by = 'REFRESH USR 2C',
                                   r_user.pwd_regen_flag = 'Y',
                                   R_USER.DT_RESET_PASSWORD_UPDATED = SYSDATE
                 WHERE user_id = lv_user_id;
               END IF;
               -- no else needed, the user is already active.
         -- No active contract owned/served.
         ELSE
            -- set to inactive
              IF (v_cur_status <> 'I')
                 THEN
                UPDATE r_user
                   SET status = 'I', DT_UPDATED = SYSDATE, r_user.UPDATED_BY='REFRESH USR 2C'
                 WHERE user_id = lv_user_id; 
               END IF;
         END IF;
      END LOOP;
      -- 2d. user_role = advisor only 
      OPEN c_advr (v_eod_refresh_user);
      -- check if the user served any active contract for company 2/3 AND IFSDMAGLPF.DTETRM > todays, if exists set status = 'A'
        -- if NONE exists, set status = 'I'                                
            LOOP
         FETCH c_advr
          INTO lv_user_id, lv_agntcoy;
         EXIT WHEN c_advr%NOTFOUND;
          -- get the list of active contract served by the advisor
         SELECT COUNT (DISTINCT ui.user_id)
           INTO v_ctr_served_chdr
           FROM ifsdmchdrpf chdr, ifsdmaglfpf ag, r_user_info ui
          WHERE chdr.servagnt = ag.agntnum
            AND ag.clntnum = ui.clntnum
            AND chdr.chdrcoy IN (lv_agntcoy)
            AND chdr.statcode IN ('AC', 'IF')
            AND ui.user_id = lv_user_id;
         -- get the current status first.
                 SELECT u.status 
                 INTO v_cur_status
                 FROM R_USER u where u.user_id = lv_user_id;
         IF (v_ctr_served_chdr > 0) 
         THEN                 
                 -- it was inactive before, so need to reset the password as well.
                 IF (v_cur_status = 'I')
                 THEN
                -- set to active
                UPDATE r_user
                   SET -- status = 'A',
                       dt_updated = SYSDATE,
                               r_user.updated_by = 'REFRESH USR 2D',
                                   r_user.pwd_regen_flag = 'Y',
                                   R_USER.DT_RESET_PASSWORD_UPDATED = SYSDATE
                 WHERE user_id = lv_user_id;
               END IF;
         -- No active contract served.
           ELSE
              -- set to inactive
              IF (v_cur_status <> 'I')
                 THEN
                  UPDATE r_user
                     SET status = 'I', DT_UPDATED = SYSDATE, r_user.UPDATED_BY='REFRESH USR 2D'
                   WHERE user_id = lv_user_id; 
                 END IF;
           END IF;
      END LOOP;
      -- 2e. user_role = investor only
      -- check if the user has active contract owned (jointly/individually), if exists, set status = 'A'
           -- if NONE exists, set status = 'I'
      open c_inv (v_eod_refresh_user);
      LOOP
         FETCH c_inv
          INTO lv_user_id;
         EXIT WHEN c_inv%NOTFOUND;
         -- search the active contract owned by the user
         SELECT COUNT (DISTINCT i.user_id)
           INTO v_ctr_owned_chdr
                    FROM IFSDMCHDRPF ch, R_USER_INFO i
                   WHERE ch.statcode IN ('AC', 'IF')
                     AND ch.chdrcoy in ('2','3')
                     AND (i.clntnum = ch.cownnum OR i.clntnum = ch.jownnum)
                     AND i.user_id = lv_user_id;
                 -- get the current status first.
                 SELECT u.status 
                 INTO v_cur_status
                 FROM R_USER u where u.user_id = lv_user_id;
         -- found the contract? yes!
         IF (v_ctr_owned_chdr > 0)
         THEN
                 -- it was inactive before, so need to reset the password as well.
                 IF (v_cur_status = 'I')
                 THEN
                -- set to active
                UPDATE r_user
                   SET -- status = 'A',
                       dt_updated = SYSDATE,
                               r_user.updated_by = 'REFRESH USR 2E',
                                   r_user.pwd_regen_flag = 'Y',
                                   R_USER.DT_RESET_PASSWORD_UPDATED = SYSDATE
                 WHERE user_id = lv_user_id;
               END IF;
               -- no else needed, the user is already active.
         -- No active contract owned.
         ELSE
            -- set to inactive
            IF (v_cur_status <> 'I')
                 THEN
                UPDATE r_user
                   SET status = 'I', DT_UPDATED = SYSDATE, r_user.UPDATED_BY='REFRESH USR 2E'
                 WHERE user_id = lv_user_id; 
               END IF; --- end if to check the current status.  if it is INACTIVE currently, no need to update to inactive anymore.
         END IF;
      END LOOP;
       inserteodlog ('REFRESH USR', 'S');
   EXCEPTION
      WHEN OTHERS
      THEN
         IF c_invtr_and_advr%ISOPEN
         THEN
            CLOSE c_invtr_and_advr;
         END IF;
         IF c_advr%ISOPEN
         THEN
            CLOSE c_advr;
         END IF;
         IF c_inv%ISOPEN
         THEN
            CLOSE c_inv;
         END IF;
         IF c_others%ISOPEN
         THEN
            CLOSE c_others;
         END IF;
         inserteodlog ('REFRESH USR', 'F', SQLERRM);
-- COMMIT;
   END;
   ----------------------------------- v2.9 end -------------------------------------- 


END Eodproc;
/
