//! NovaSector 全量汉化 (i18n) —— DM 字符串抽取/改写工具。
//!
//! 首版 `extract` 聚焦类型变量初始化里的玩家可见文本（name/desc 等，即「动态渲染」内容的
//! 主要来源），输出英文主目录 strings/i18n/en/<namespace>.json。
//! 后续增量将扩展到 proc 体内的 to_chat / visible_message / balloon_alert 等汇聚点，
//! 并把内插字符串转换为 {0}/{1} 占位符模板、改写调用点为 LANG/LANGU。

mod catalog;
mod extract;
mod keys;
mod rewrite;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "nova-i18n", about = "NovaSector 全量汉化抽取/改写工具")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// 解析 .dme 并抽取玩家可见字符串到英文目录。
    Extract {
        /// 项目入口 .dme。
        #[arg(long, default_value = "tgstation.dme")]
        dme: PathBuf,
        /// 英文主目录输出位置。
        #[arg(long, default_value = "strings/i18n/en")]
        out: PathBuf,
        /// 只统计、不落盘。
        #[arg(long)]
        dry_run: bool,
    },
    /// 幂等改写：把汇聚点调用里的纯字符串消息替换为 LANG("key", null)（v1）。
    Rewrite {
        /// 项目入口 .dme。
        #[arg(long, default_value = "tgstation.dme")]
        dme: PathBuf,
        /// 仅改写路径包含该子串的文件（建议分域/分模块逐步推进）。
        #[arg(long)]
        filter: Option<String>,
        /// 只统计、不落盘。
        #[arg(long)]
        dry_run: bool,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Extract { dme, out, dry_run } => extract::run(&dme, &out, dry_run),
        Cmd::Rewrite {
            dme,
            filter,
            dry_run,
        } => rewrite::run(&dme, filter.as_deref(), dry_run),
    }
}
