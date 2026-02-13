


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."set_notes_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
    new.updated_at = now();
    return new;
end;
$$;


ALTER FUNCTION "public"."set_notes_updated_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_notes_updated_at"() IS '在更新 notes 表记录时，自动刷新 updated_at 字段';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."binance_buy_usdt" (
    "order_number" "text" NOT NULL,
    "adv_no" "text",
    "trade_type" "text",
    "asset" "text",
    "fiat" "text",
    "fiat_symbol" "text",
    "amount" numeric,
    "total_price" numeric,
    "unit_price" numeric,
    "order_status" "text",
    "create_time" bigint,
    "commission" numeric,
    "taker_commission_rate" numeric,
    "taker_commission" numeric,
    "taker_amount" numeric,
    "counter_part_nick_name" "text",
    "pay_method_name" "text",
    "additional_kyc_verify" integer
);


ALTER TABLE "public"."binance_buy_usdt" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."binance_buy_usdt_summary" AS
 SELECT "asset",
    "sum"("amount") AS "total_amount",
    "sum"("total_price") AS "total_price",
    "count"(*) AS "total_orders"
   FROM "public"."binance_buy_usdt"
  GROUP BY "asset"
  ORDER BY ("sum"("amount")) DESC;


ALTER VIEW "public"."binance_buy_usdt_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."binance_trades" (
    "symbol" "text" NOT NULL,
    "trade_id" bigint NOT NULL,
    "order_id" bigint,
    "price" numeric,
    "qty" numeric,
    "quote_qty" numeric,
    "commission" numeric,
    "commission_asset" "text",
    "trade_time" bigint,
    "is_buyer" boolean,
    "is_maker" boolean,
    "is_best_match" boolean,
    "is_isolated" "text"
);


ALTER TABLE "public"."binance_trades" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ibkr_trad" (
    "asset" "text" NOT NULL,
    "symbol" "text" NOT NULL,
    "trade_time" timestamp without time zone NOT NULL,
    "qty" numeric NOT NULL,
    "price" numeric NOT NULL,
    "proceeds" numeric NOT NULL,
    "fee" numeric NOT NULL,
    "add_info" "text",
    "id" bigint NOT NULL
);


ALTER TABLE "public"."ibkr_trad" OWNER TO "postgres";


ALTER TABLE "public"."ibkr_trad" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."ibkr_trad_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."ibkr_view_bond" AS
 SELECT '债息和'::"text" AS "symbol",
    "sum"("proceeds") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '债券利息'::"text");


ALTER VIEW "public"."ibkr_view_bond" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_cash_forex" AS
 SELECT "symbol",
    "total_proceeds"
   FROM ( SELECT "t"."symbol",
            "sum"("t"."amount") AS "total_proceeds"
           FROM ( SELECT "ibkr_trad"."symbol",
                    "ibkr_trad"."proceeds" AS "amount"
                   FROM "public"."ibkr_trad"
                  WHERE ("ibkr_trad"."asset" = '存款'::"text")
                UNION ALL
                 SELECT "ibkr_trad"."symbol",
                    "ibkr_trad"."qty" AS "amount"
                   FROM "public"."ibkr_trad"
                  WHERE ("ibkr_trad"."asset" = '外汇'::"text")) "t"
          GROUP BY "t"."symbol"
        UNION ALL
         SELECT '美元和'::"text" AS "symbol",
            "sum"("s"."amount") AS "total_proceeds"
           FROM ( SELECT
                        CASE
                            WHEN ("ibkr_trad"."symbol" = ANY (ARRAY['USD.HKD'::"text", 'USD.CNH'::"text", 'USD'::"text"])) THEN
                            CASE
                                WHEN ("ibkr_trad"."asset" = '存款'::"text") THEN "ibkr_trad"."proceeds"
                                WHEN ("ibkr_trad"."asset" = '外汇'::"text") THEN "ibkr_trad"."qty"
                                ELSE NULL::numeric
                            END
                            ELSE NULL::numeric
                        END AS "amount"
                   FROM "public"."ibkr_trad"
                  WHERE ("ibkr_trad"."asset" = ANY (ARRAY['存款'::"text", '外汇'::"text"]))) "s"
          WHERE ("s"."amount" IS NOT NULL)) "final"
  ORDER BY ("symbol" = 'USD_SUM'::"text"), ("symbol" ~~ '%.%'::"text") DESC, ("symbol" ~~ 'USD.%'::"text") DESC, "symbol";


ALTER VIEW "public"."ibkr_view_cash_forex" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_dividend" AS
 SELECT "symbol",
    "sum"("proceeds") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '红利'::"text")
  GROUP BY "symbol";


ALTER VIEW "public"."ibkr_view_dividend" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_dividend_total" AS
 SELECT "sorted_dividends"."symbol",
    "sorted_dividends"."total_proceeds"
   FROM ( SELECT "ibkr_view_dividend"."symbol",
            "ibkr_view_dividend"."total_proceeds"
           FROM "public"."ibkr_view_dividend"
          ORDER BY "ibkr_view_dividend"."total_proceeds") "sorted_dividends"
UNION ALL
 SELECT '股息和'::"text" AS "symbol",
    "sum"("ibkr_view_dividend"."total_proceeds") AS "total_proceeds"
   FROM "public"."ibkr_view_dividend";


ALTER VIEW "public"."ibkr_view_dividend_total" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_option_total" AS
 SELECT "sorted_options"."symbol",
    "sorted_options"."total_proceeds"
   FROM ( SELECT "ibkr_trad"."symbol",
            "sum"("ibkr_trad"."proceeds") AS "total_proceeds"
           FROM "public"."ibkr_trad"
          WHERE ("ibkr_trad"."asset" = '期权'::"text")
          GROUP BY "ibkr_trad"."symbol"
          ORDER BY ("sum"("ibkr_trad"."proceeds"))) "sorted_options"
UNION ALL
 SELECT '期权和'::"text" AS "symbol",
    "sum"("ibkr_trad"."proceeds") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("ibkr_trad"."asset" = '期权'::"text");


ALTER VIEW "public"."ibkr_view_option_total" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_stock_closed" AS
 SELECT "symbol",
    "sum"("qty") AS "position_qty",
    "sum"("proceeds") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '股票'::"text")
  GROUP BY "symbol"
 HAVING ("sum"("qty") = (0)::numeric)
  ORDER BY ("sum"("proceeds"));


ALTER VIEW "public"."ibkr_view_stock_closed" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_stock_closed_total" AS
 SELECT "ibkr_view_stock_closed"."symbol",
    "ibkr_view_stock_closed"."total_proceeds"
   FROM "public"."ibkr_view_stock_closed"
UNION ALL
 SELECT '己清仓'::"text" AS "symbol",
    "sum"("ibkr_view_stock_closed"."total_proceeds") AS "total_proceeds"
   FROM "public"."ibkr_view_stock_closed";


ALTER VIEW "public"."ibkr_view_stock_closed_total" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_stock_position" AS
 SELECT "symbol",
    "sum"("qty") AS "position_qty",
    (- "sum"("proceeds")) AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '股票'::"text")
  GROUP BY "symbol"
 HAVING ("sum"("qty") <> (0)::numeric);


ALTER VIEW "public"."ibkr_view_stock_position" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_stock_position_avg" AS
 SELECT "symbol",
    "position_qty",
    "total_proceeds",
    ("total_proceeds" / "position_qty") AS "avg_price"
   FROM "public"."ibkr_view_stock_position"
  ORDER BY "total_proceeds" DESC;


ALTER VIEW "public"."ibkr_view_stock_position_avg" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_all" AS
 SELECT '持仓'::"text" AS "category",
    "ibkr_view_stock_position_avg"."symbol",
    "ibkr_view_stock_position_avg"."position_qty" AS "qty",
    "ibkr_view_stock_position_avg"."avg_price",
    "ibkr_view_stock_position_avg"."total_proceeds"
   FROM "public"."ibkr_view_stock_position_avg"
UNION ALL
 SELECT '清仓'::"text" AS "category",
    "ibkr_view_stock_closed_total"."symbol",
    NULL::numeric AS "qty",
    NULL::numeric AS "avg_price",
    "ibkr_view_stock_closed_total"."total_proceeds"
   FROM "public"."ibkr_view_stock_closed_total"
UNION ALL
 SELECT '期权'::"text" AS "category",
    "ibkr_view_option_total"."symbol",
    NULL::numeric AS "qty",
    NULL::numeric AS "avg_price",
    "ibkr_view_option_total"."total_proceeds"
   FROM "public"."ibkr_view_option_total"
UNION ALL
 SELECT '红利'::"text" AS "category",
    "ibkr_view_dividend_total"."symbol",
    NULL::numeric AS "qty",
    NULL::numeric AS "avg_price",
    "ibkr_view_dividend_total"."total_proceeds"
   FROM "public"."ibkr_view_dividend_total"
UNION ALL
 SELECT '债券利息'::"text" AS "category",
    "ibkr_view_bond"."symbol",
    NULL::numeric AS "qty",
    NULL::numeric AS "avg_price",
    "ibkr_view_bond"."total_proceeds"
   FROM "public"."ibkr_view_bond"
UNION ALL
 SELECT '外汇汇款'::"text" AS "category",
    "ibkr_view_cash_forex"."symbol",
    NULL::numeric AS "qty",
    NULL::numeric AS "avg_price",
    "ibkr_view_cash_forex"."total_proceeds"
   FROM "public"."ibkr_view_cash_forex";


ALTER VIEW "public"."ibkr_view_all" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_deposits" AS
 SELECT "symbol",
    "sum"("proceeds") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '存款'::"text")
  GROUP BY "symbol";


ALTER VIEW "public"."ibkr_view_deposits" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_forex" AS
 SELECT "symbol",
    "sum"("qty") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '外汇'::"text")
  GROUP BY "symbol";


ALTER VIEW "public"."ibkr_view_forex" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ibkr_view_option" AS
 SELECT "symbol",
    "sum"("proceeds") AS "total_proceeds"
   FROM "public"."ibkr_trad"
  WHERE ("asset" = '期权'::"text")
  GROUP BY "symbol";


ALTER VIEW "public"."ibkr_view_option" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text",
    "content" "text" NOT NULL,
    "tags" "text"[],
    "is_archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notes" OWNER TO "postgres";


COMMENT ON TABLE "public"."notes" IS '私人笔记 / 记录表，用于存储个人 Markdown 文本记录，仅供本人使用';



COMMENT ON COLUMN "public"."notes"."id" IS '主键，UUID，自动生成';



COMMENT ON COLUMN "public"."notes"."title" IS '笔记标题，可为空';



COMMENT ON COLUMN "public"."notes"."content" IS '笔记正文内容，Markdown 格式文本';



COMMENT ON COLUMN "public"."notes"."tags" IS '标签数组，用于分类和筛选';



COMMENT ON COLUMN "public"."notes"."is_archived" IS '是否归档：true=已归档，false=正常';



COMMENT ON COLUMN "public"."notes"."created_at" IS '记录创建时间';



COMMENT ON COLUMN "public"."notes"."updated_at" IS '记录最后更新时间';



CREATE TABLE IF NOT EXISTS "public"."taobao_stock_qty" (
    "英文代码" "text",
    "产品名称" "text",
    "库存量" bigint,
    "批发价" bigint
);


ALTER TABLE "public"."taobao_stock_qty" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_net_positions" AS
 SELECT "symbol",
    "sum"(
        CASE
            WHEN (("is_buyer" = true) AND ("commission_asset" = "symbol")) THEN ("qty" - "commission")
            WHEN ("is_buyer" = true) THEN "qty"
            WHEN ("is_buyer" = false) THEN (- "qty")
            ELSE (0)::numeric
        END) AS "net_qty",
    "sum"(
        CASE
            WHEN (("is_buyer" = true) AND ("commission_asset" <> "symbol")) THEN ("quote_qty" + "commission")
            WHEN ("is_buyer" = true) THEN "quote_qty"
            ELSE (0)::numeric
        END) AS "total_buy_cost",
    "sum"(
        CASE
            WHEN (("is_buyer" = true) AND ("commission_asset" = "symbol")) THEN ("qty" - "commission")
            WHEN ("is_buyer" = true) THEN "qty"
            ELSE (0)::numeric
        END) AS "total_buy_qty"
   FROM "public"."binance_trades"
  GROUP BY "symbol";


ALTER VIEW "public"."v_net_positions" OWNER TO "postgres";


ALTER TABLE ONLY "public"."binance_buy_usdt"
    ADD CONSTRAINT "binance_buy_usdt_pkey" PRIMARY KEY ("order_number");



ALTER TABLE ONLY "public"."ibkr_trad"
    ADD CONSTRAINT "ibkr_trad_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ibkr_trad"
    ADD CONSTRAINT "ibkr_trad_unique" UNIQUE ("asset", "symbol", "trade_time", "qty", "price", "proceeds", "fee", "add_info");



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."binance_trades"
    ADD CONSTRAINT "uniq_symbol_trade" UNIQUE ("symbol", "trade_id");



CREATE INDEX "notes_archived_idx" ON "public"."notes" USING "btree" ("is_archived");



CREATE INDEX "notes_created_at_idx" ON "public"."notes" USING "btree" ("created_at" DESC);



CREATE INDEX "notes_tags_idx" ON "public"."notes" USING "gin" ("tags");



CREATE OR REPLACE TRIGGER "trigger_notes_updated_at" BEFORE UPDATE ON "public"."notes" FOR EACH ROW EXECUTE FUNCTION "public"."set_notes_updated_at"();



COMMENT ON TRIGGER "trigger_notes_updated_at" ON "public"."notes" IS '更新 notes 记录前，自动更新 updated_at 时间戳';





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."set_notes_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_notes_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_notes_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."binance_buy_usdt" TO "anon";
GRANT ALL ON TABLE "public"."binance_buy_usdt" TO "authenticated";
GRANT ALL ON TABLE "public"."binance_buy_usdt" TO "service_role";



GRANT ALL ON TABLE "public"."binance_buy_usdt_summary" TO "anon";
GRANT ALL ON TABLE "public"."binance_buy_usdt_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."binance_buy_usdt_summary" TO "service_role";



GRANT ALL ON TABLE "public"."binance_trades" TO "anon";
GRANT ALL ON TABLE "public"."binance_trades" TO "authenticated";
GRANT ALL ON TABLE "public"."binance_trades" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_trad" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_trad" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_trad" TO "service_role";



GRANT ALL ON SEQUENCE "public"."ibkr_trad_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."ibkr_trad_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."ibkr_trad_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_bond" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_bond" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_bond" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_cash_forex" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_cash_forex" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_cash_forex" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_dividend" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_dividend" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_dividend" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_dividend_total" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_dividend_total" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_dividend_total" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_option_total" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_option_total" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_option_total" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_stock_closed" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_stock_closed" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_stock_closed" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_stock_closed_total" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_stock_closed_total" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_stock_closed_total" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_stock_position" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_stock_position" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_stock_position" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_stock_position_avg" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_stock_position_avg" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_stock_position_avg" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_all" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_all" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_all" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_deposits" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_deposits" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_deposits" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_forex" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_forex" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_forex" TO "service_role";



GRANT ALL ON TABLE "public"."ibkr_view_option" TO "anon";
GRANT ALL ON TABLE "public"."ibkr_view_option" TO "authenticated";
GRANT ALL ON TABLE "public"."ibkr_view_option" TO "service_role";



GRANT ALL ON TABLE "public"."notes" TO "anon";
GRANT ALL ON TABLE "public"."notes" TO "authenticated";
GRANT ALL ON TABLE "public"."notes" TO "service_role";



GRANT ALL ON TABLE "public"."taobao_stock_qty" TO "anon";
GRANT ALL ON TABLE "public"."taobao_stock_qty" TO "authenticated";
GRANT ALL ON TABLE "public"."taobao_stock_qty" TO "service_role";



GRANT ALL ON TABLE "public"."v_net_positions" TO "anon";
GRANT ALL ON TABLE "public"."v_net_positions" TO "authenticated";
GRANT ALL ON TABLE "public"."v_net_positions" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































