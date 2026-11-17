# -*- coding: utf-8 -*-
"""
把本地 UserBehavior.csv 导入 Aiven MySQL。
密码不写在文件里：运行时会被问一次（避免传到 GitHub 泄露）。
"""
import csv
import os
import time

import pymysql

HOST = "mysql-1760b1f0-project-ea2e.b.aivencloud.com"
PORT = 25783
USER = "avnadmin"
DATABASE = "defaultdb"
CA_PATH = "C:/Users/Admin/Downloads/ca.pem"   # 证书路径，按自己电脑改

CSV_PATH = "UserBehavior.csv"   # 和本脚本放在同一个文件夹
TARGET_ROWS = 500000            # 目标行数：50 万
BATCH_SIZE = 20000              # 每批提交 2 万行
TRUNCATE_FIRST = True           # 先清空表，避免和旧数据重复


def get_password():
    pwd = os.getenv("DB_PASSWORD")
    if pwd:
        return pwd
    return input("请输入 Aiven 数据库密码：")


def main():
    conn = pymysql.connect(
        host=HOST, port=PORT, user=USER, password=get_password(),
        database=DATABASE, ssl={"ca": CA_PATH},
        charset="utf8mb4", connect_timeout=15,
    )
    cursor = conn.cursor()
    print("连接成功")

    if TRUNCATE_FIRST:
        cursor.execute("TRUNCATE TABLE user_behavior")
        conn.commit()
        print("已清空 user_behavior（旧数据会被替换成 CSV 里的真实数据）")

    sql = ("INSERT INTO user_behavior "
           "(user_id, item_id, category_id, behavior_type, timestamp) "
           "VALUES (%s, %s, %s, %s, %s)")

    batch, total, start = [], 0, time.time()
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        for row in csv.reader(f):
            if len(row) < 5:
                continue
            batch.append((int(row[0]), int(row[1]), int(row[2]), row[3], int(row[4])))
            if len(batch) >= BATCH_SIZE:
                cursor.executemany(sql, batch)
                conn.commit()
                total += len(batch)
                batch.clear()
                print(f"已导入 {total} 行 ... {time.time() - start:.0f}s")
                if total >= TARGET_ROWS:
                    break
        if batch and total < TARGET_ROWS:
            cursor.executemany(sql, batch)
            conn.commit()
            total += len(batch)

    cursor.execute("SELECT COUNT(*) FROM user_behavior")
    print("表里现有", cursor.fetchone()[0], "行")
    print(f"完成，用时 {time.time() - start:.0f}s")
    cursor.close()
    conn.close()


if __name__ == "__main__":
    main()
