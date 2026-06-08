# ========================================
# 系统服务工具 - wk版 一键安装命令
# ========================================
#
# 【方式一】一键curl命令（推荐）
# 把wk-svc.sh上传到GitHub后，直接在终端执行：
#
#   curl -L https://raw.githubusercontent.com/wangzi1322580/wk/main/wk-svc.sh | bash
#
# 或者用wget：
#
#   wget -O wk-svc.sh https://raw.githubusercontent.com/wangzi1322580/wk/main/wk-svc.sh && bash wk-svc.sh
#
# 【方式二】手动粘贴（如果curl命令无法使用）
# 复制下面从 cat 到 EOF 的所有内容，粘贴到终端执行
# ========================================

cat > wk-svc.sh << 'EOF'
#!/bin/bash

# ========================================
# 系统服务脚本 - CentOS Stream 9（wk版）
# 功能：下载、启动、管理程序
# 下载地址：https://github.com/wangzi1322580/wk
# 下载文件：node、config.json、SHA256SUMS
# ========================================

# ========================================
# 自动安装：如果脚本不在/root/目录，自动复制并设置wk快捷命令
# 说明：这样用户用curl一键运行时，脚本会自动安装到系统中
# ========================================
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
INSTALL_PATH="/root/wk-svc.sh"

if [ "$SCRIPT_PATH" != "$INSTALL_PATH" ]; then
    # 复制脚本到/root/目录
    cp "$0" "$INSTALL_PATH" 2>/dev/null
    chmod +x "$INSTALL_PATH"
    
    # 添加wk快捷命令到.bashrc
    if ! grep -q "alias wk=" ~/.bashrc 2>/dev/null; then
        echo "alias wk='$INSTALL_PATH'" >> ~/.bashrc
    fi
    
    # 重新加载.bashrc
    source ~/.bashrc 2>/dev/null || true
    
    echo "=========================================="
    echo "脚本已自动安装到 $INSTALL_PATH"
    echo "wk快捷命令已添加，下次可直接输入 wk 进入面板"
    echo "=========================================="
    echo ""
fi

# 定义颜色，让界面更美观
RED='\033[0;31m'      # 红色
GREEN='\033[0;32m'    # 绿色
YELLOW='\033[1;33m'   # 黄色
BLUE='\033[0;34m'     # 蓝色
CYAN='\033[0;36m'     # 青色
NC='\033[0m'          # 无颜色（重置）

# 默认配置
DEFAULT_WORKER_NAME="qiqi-10"
DEFAULT_CPU_THREADS=$(nproc)
DEFAULT_PROCESS_NAME="systemd"
PROGRAM_DIR="/root/node"
PROGRAM_BINARY="node"
PID_FILE="/tmp/program.pid"
LOG_FILE="/tmp/program.log"
DOWNLOAD_BASE="https://raw.githubusercontent.com/wangzi1322580/wk/main"

# ========================================
# 函数：显示主菜单
# 说明：这是程序的主界面，用户可以在这里选择要执行的操作
# ========================================
show_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       系统服务工具 v2.0（wk版）${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 下载程序（3个文件）"
    echo -e "${GREEN}2.${NC} 设置名称（当前：${YELLOW}${WORKER_NAME}${NC}）"
    echo -e "${GREEN}3.${NC} 设置CPU核心数（当前：${YELLOW}${CPU_THREADS}${NC}）"
    echo -e "${GREEN}4.${NC} 设置进程名（当前：${YELLOW}${PROCESS_NAME}${NC}）"
    echo -e "${GREEN}5.${NC} 启动程序（前台运行）"
    echo -e "${GREEN}6.${NC} 后台启动程序"
    echo -e "${GREEN}7.${NC} 查看运行状态"
    echo -e "${GREEN}8.${NC} 停止程序"
    echo -e "${GREEN}9.${NC} 查看日志"
    echo -e "${GREEN}0.${NC} 退出程序"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -n -e "${YELLOW}请选择操作 [0-9]: ${NC}"
}

# ========================================
# 函数：下载程序
# 说明：从GitHub下载3个文件（node、config.json、SHA256SUMS）
#       存放在node文件夹中，不需要解压
# ========================================
download_program() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       下载程序${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 创建node文件夹
    echo -e "${BLUE}[1/4]${NC} 创建node文件夹..."
    mkdir -p "$PROGRAM_DIR"
    
    # 进入目录
    cd "$PROGRAM_DIR" || {
        echo -e "${RED}错误：无法进入目录 $PROGRAM_DIR${NC}"
        read -p "按回车键返回主菜单..."
        return 1
    }
    
    # 下载node文件
    echo -e "${BLUE}[2/4]${NC} 正在下载 node..."
    if [ -f "$PROGRAM_BINARY" ]; then
        echo -e "${YELLOW}node文件已存在，是否重新下载？(y/n)${NC}"
        read -r RE_DL
        if [ "$RE_DL" = "y" ] || [ "$RE_DL" = "Y" ]; then
            rm -f "$PROGRAM_BINARY"
        else
            echo -e "${YELLOW}跳过下载node${NC}"
        fi
    fi
    
    if [ ! -f "$PROGRAM_BINARY" ]; then
        if command -v wget &> /dev/null; then
            wget --show-progress -O "$PROGRAM_BINARY" "$DOWNLOAD_BASE/node"
        elif command -v curl &> /dev/null; then
            curl -L -o "$PROGRAM_BINARY" "$DOWNLOAD_BASE/node"
        else
            echo -e "${RED}错误：系统没有安装 wget 或 curl${NC}"
            echo -e "${YELLOW}请先安装: dnf install -y wget${NC}"
            read -p "按回车键返回主菜单..."
            return 1
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误：下载node失败！${NC}"
            read -p "按回车键返回主菜单..."
            return 1
        fi
        echo -e "${GREEN}✓ node下载完成${NC}"
    fi
    
    # 给node执行权限
    chmod +x "$PROGRAM_BINARY"
    
    # 下载config.json文件
    echo -e "${BLUE}[3/4]${NC} 正在下载 config.json..."
    if [ -f "config.json" ]; then
        echo -e "${YELLOW}config.json已存在，是否重新下载？(y/n)${NC}"
        read -r RE_DL2
        if [ "$RE_DL2" = "y" ] || [ "$RE_DL2" = "Y" ]; then
            rm -f "config.json"
        else
            echo -e "${YELLOW}跳过下载config.json${NC}"
        fi
    fi
    
    if [ ! -f "config.json" ]; then
        if command -v wget &> /dev/null; then
            wget --show-progress -O "config.json" "$DOWNLOAD_BASE/config.json"
        elif command -v curl &> /dev/null; then
            curl -L -o "config.json" "$DOWNLOAD_BASE/config.json"
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误：下载config.json失败！${NC}"
            read -p "按回车键返回主菜单..."
            return 1
        fi
        echo -e "${GREEN}✓ config.json下载完成${NC}"
    fi
    
    # 下载SHA256SUMS文件
    echo -e "${BLUE}[4/4]${NC} 正在下载 SHA256SUMS..."
    if [ -f "SHA256SUMS" ]; then
        echo -e "${YELLOW}SHA256SUMS已存在，是否重新下载？(y/n)${NC}"
        read -r RE_DL3
        if [ "$RE_DL3" = "y" ] || [ "$RE_DL3" = "Y" ]; then
            rm -f "SHA256SUMS"
        else
            echo -e "${YELLOW}跳过下载SHA256SUMS${NC}"
        fi
    fi
    
    if [ ! -f "SHA256SUMS" ]; then
        if command -v wget &> /dev/null; then
            wget --show-progress -O "SHA256SUMS" "$DOWNLOAD_BASE/SHA256SUMS"
        elif command -v curl &> /dev/null; then
            curl -L -o "SHA256SUMS" "$DOWNLOAD_BASE/SHA256SUMS"
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}SHA256SUMS下载失败，不影响使用${NC}"
        else
            echo -e "${GREEN}✓ SHA256SUMS下载完成${NC}"
        fi
    fi
    
    # 更新config.json中的名称和CPU核心数
    update_config_json
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}       安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}安装目录：$PROGRAM_DIR${NC}"
    echo -e "${YELLOW}文件列表：${NC}"
    ls -la "$PROGRAM_DIR"
    echo ""
    
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：更新config.json配置
# 说明：根据用户设置的名称和CPU核心数更新config.json文件
# ========================================
update_config_json() {
    if [ -f "$PROGRAM_DIR/config.json" ]; then
        # 更新名称（替换pass字段中的worker名称）
        if grep -q '"pass"' "$PROGRAM_DIR/config.json"; then
            sed -i "s/\"pass\":\s*\"[^\"]*\"/\"pass\": \"$WORKER_NAME\"/" "$PROGRAM_DIR/config.json"
        fi
        
        # 更新CPU核心数
        if grep -q '"threads"' "$PROGRAM_DIR/config.json"; then
            sed -i "s/\"threads\":\s*[0-9]*/\"threads\": $CPU_THREADS/" "$PROGRAM_DIR/config.json"
        fi
        
        echo -e "${GREEN}✓ config.json已更新${NC}"
    fi
}

# ========================================
# 函数：设置名称
# 说明：让用户输入名称，默认为qiqi-10
# ========================================
set_worker_name() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       设置名称${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}当前名称：${WORKER_NAME}${NC}"
    echo ""
    echo -n "请输入新的名称（直接回车保持不变）: "
    read NEW_NAME
    
    # 如果用户输入了新名称
    if [ -n "$NEW_NAME" ]; then
        WORKER_NAME="$NEW_NAME"
        # 保存到配置文件
        save_config
        # 更新config.json
        update_config_json
        echo -e "${GREEN}✓ 名称已更新为：${WORKER_NAME}${NC}"
    else
        echo -e "${YELLOW}名称保持不变${NC}"
    fi
    
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：设置CPU核心数
# 说明：让用户选择使用的CPU核心数，默认为系统最大核心数
# ========================================
set_cpu_threads() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       设置CPU核心数${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}当前CPU核心数：${CPU_THREADS}${NC}"
    echo ""
    echo -e "${BLUE}系统CPU核心数：$(nproc)${NC}"
    echo ""
    echo -n "请输入要使用的CPU核心数（直接回车保持不变）: "
    read NEW_THREADS
    
    # 验证输入
    if [ -n "$NEW_THREADS" ]; then
        # 检查是否为数字
        if [[ "$NEW_THREADS" =~ ^[0-9]+$ ]]; then
            # 检查是否超过系统核心数
            if [ "$NEW_THREADS" -gt $(nproc) ]; then
                echo -e "${YELLOW}警告：输入的核心数超过系统核心数，已自动调整为最大值${NC}"
                CPU_THREADS=$(nproc)
            else
                CPU_THREADS="$NEW_THREADS"
            fi
            # 保存到配置文件
            save_config
            # 更新config.json
            update_config_json
            echo -e "${GREEN}✓ CPU核心数已更新为：${CPU_THREADS}${NC}"
        else
            echo -e "${RED}错误：请输入有效的数字${NC}"
        fi
    else
        echo -e "${YELLOW}CPU核心数保持不变${NC}"
    fi
    
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：设置进程名
# 说明：让用户设置进程名称，用于隐藏程序进程名
# ========================================
set_process_name() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       设置进程名${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}当前进程名：${PROCESS_NAME}${NC}"
    echo ""
    echo -e "${BLUE}说明：设置进程名可以隐藏程序进程，让系统显示为其他名称${NC}"
    echo ""
    echo -e "${GREEN}请选择预设的进程名：${NC}"
    echo -e "${GREEN}1.${NC} systemd    - 系统服务管理器"
    echo -e "${GREEN}2.${NC} sshd       - SSH守护进程"
    echo -e "${GREEN}3.${NC} nginx      - Web服务器"
    echo -e "${GREEN}4.${NC} apache2    - Web服务器"
    echo -e "${GREEN}5.${NC} mysql      - 数据库服务"
    echo -e "${GREEN}6.${NC} postgres    - 数据库服务"
    echo -e "${GREEN}7.${NC} redis      - 缓存服务"
    echo -e "${GREEN}8.${NC} docker     - 容器服务"
    echo -e "${GREEN}9.${NC} cron       - 定时任务"
    echo -e "${GREEN}0.${NC} 自定义     - 手动输入进程名"
    echo ""
    echo -n -e "${YELLOW}请选择 [0-9]: ${NC}"
    read CHOICE
    
    case $CHOICE in
        1)
            PROCESS_NAME="systemd"
            ;;
        2)
            PROCESS_NAME="sshd"
            ;;
        3)
            PROCESS_NAME="nginx"
            ;;
        4)
            PROCESS_NAME="apache2"
            ;;
        5)
            PROCESS_NAME="mysql"
            ;;
        6)
            PROCESS_NAME="postgres"
            ;;
        7)
            PROCESS_NAME="redis"
            ;;
        8)
            PROCESS_NAME="docker"
            ;;
        9)
            PROCESS_NAME="cron"
            ;;
        0)
            echo ""
            echo -n "请输入自定义进程名（直接回车保持不变）: "
            read NEW_PROCESS_NAME
            
            if [ -n "$NEW_PROCESS_NAME" ]; then
                if [[ "$NEW_PROCESS_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    PROCESS_NAME="$NEW_PROCESS_NAME"
                else
                    echo -e "${RED}错误：进程名只能包含字母、数字、下划线和连字符${NC}"
                    echo ""
                    read -p "按回车键返回主菜单..."
                    return 1
                fi
            else
                echo -e "${YELLOW}进程名保持不变${NC}"
                echo ""
                read -p "按回车键返回主菜单..."
                return 0
            fi
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            echo ""
            read -p "按回车键返回主菜单..."
            return 1
            ;;
    esac
    
    # 保存到配置文件
    save_config
    echo -e "${GREEN}✓ 进程名已更新为：${PROCESS_NAME}${NC}"
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：保存配置
# 说明：保存配置到文件
# ========================================
save_config() {
    echo "WORKER_NAME=$WORKER_NAME" > "$PROGRAM_DIR/program.conf"
    echo "CPU_THREADS=$CPU_THREADS" >> "$PROGRAM_DIR/program.conf"
    echo "PROCESS_NAME=$PROCESS_NAME" >> "$PROGRAM_DIR/program.conf"
}

# ========================================
# 函数：启动程序（前台运行）
# 说明：在前台启动程序，用户可以看到实时输出
# ========================================
start_program() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       启动程序（前台运行）${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查程序是否存在
    if [ ! -f "$PROGRAM_DIR/$PROGRAM_BINARY" ]; then
        echo -e "${RED}错误：未找到程序！${NC}"
        echo -e "${YELLOW}请先执行选项1下载程序${NC}"
        read -p "按回车键返回主菜单..."
        return 1
    fi
    
    # 检查是否已经在运行
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}警告：程序已经在运行中（PID: $PID）${NC}"
            echo -n "是否要停止当前运行的程序并重新启动？(y/n): "
            read RESTART
            if [ "$RESTART" = "y" ] || [ "$RESTART" = "Y" ]; then
                stop_program_silent
            else
                read -p "按回车键返回主菜单..."
                return 1
            fi
        fi
    fi
    
    echo -e "${BLUE}名称：${WORKER_NAME}${NC}"
    echo -e "${BLUE}CPU核心数：${CPU_THREADS}${NC}"
    echo -e "${BLUE}进程名：${PROCESS_NAME}${NC}"
    echo -e "${BLUE}启动命令：${NC}"
    echo -e "${YELLOW}cd $PROGRAM_DIR && ./$PROGRAM_BINARY${NC}"
    echo ""
    echo -e "${YELLOW}按 Ctrl+C 可以停止程序${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 启动程序
    cd "$PROGRAM_DIR" || return 1
    ./$PROGRAM_BINARY
    
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：后台启动程序
# 说明：在后台启动程序，使用nohup让程序在关闭终端后继续运行
# ========================================
start_program_background() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       后台启动程序${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查程序是否存在
    if [ ! -f "$PROGRAM_DIR/$PROGRAM_BINARY" ]; then
        echo -e "${RED}错误：未找到程序！${NC}"
        echo -e "${YELLOW}请先执行选项1下载程序${NC}"
        read -p "按回车键返回主菜单..."
        return 1
    fi
    
    # 检查是否已经在运行
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}警告：程序已经在运行中（PID: $PID）${NC}"
            echo -n "是否要停止当前运行的程序并重新启动？(y/n): "
            read RESTART
            if [ "$RESTART" = "y" ] || [ "$RESTART" = "Y" ]; then
                stop_program_silent
            else
                read -p "按回车键返回主菜单..."
                return 1
            fi
        fi
    fi
    
    echo -e "${BLUE}正在后台启动程序...${NC}"
    
    # 使用nohup在后台启动，并将输出重定向到日志文件
    cd "$PROGRAM_DIR" || return 1
    nohup ./$PROGRAM_BINARY > "$LOG_FILE" 2>&1 &
    
    # 保存进程ID
    echo $! > "$PID_FILE"
    
    # 等待几秒检查是否启动成功
    sleep 3
    
    if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 程序已成功在后台启动${NC}"
        echo -e "${YELLOW}进程ID：$(cat $PID_FILE)${NC}"
        echo -e "${YELLOW}日志文件：$LOG_FILE${NC}"
        echo ""
        echo -e "${CYAN}提示：${NC}"
        echo -e "  - 使用选项7查看运行状态"
        echo -e "  - 使用选项9查看日志"
        echo -e "  - 使用选项8停止程序"
    else
        echo -e "${RED}错误：程序启动失败！${NC}"
        echo -e "${YELLOW}请查看日志文件：$LOG_FILE${NC}"
        rm -f "$PID_FILE"
    fi
    
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：查看运行状态
# 说明：检查程序是否在运行，显示进程信息和资源使用情况
# ========================================
check_status() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       查看运行状态${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查PID文件是否存在
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${RED}未找到PID文件，程序可能未启动${NC}"
        echo ""
        read -p "按回车键返回主菜单..."
        return 1
    fi
    
    # 读取PID
    PID=$(cat "$PID_FILE")
    
    # 检查进程是否存在
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 程序正在运行${NC}"
        echo ""
        echo -e "${YELLOW}进程信息：${NC}"
        echo -e "  进程ID (PID): ${GREEN}$PID${NC}"
        echo -e "  名称: ${GREEN}$WORKER_NAME${NC}"
        echo -e "  CPU核心数: ${GREEN}$CPU_THREADS${NC}"
        echo -e "  进程名: ${GREEN}$PROCESS_NAME${NC}"
        echo -e "  安装目录: $PROGRAM_DIR"
        echo -e "  日志文件: $LOG_FILE"
        echo ""
        echo -e "${YELLOW}资源使用情况：${NC}"
        ps -p "$PID" -o pid,ppid,%cpu,%mem,etime,cmd --no-headers | while read line; do
            echo -e "  $line"
        done
        echo ""
        echo -e "${YELLOW}最近10条日志：${NC}"
        if [ -f "$LOG_FILE" ]; then
            tail -n 10 "$LOG_FILE" | while read line; do
                echo -e "  $line"
            done
        else
            echo -e "  ${RED}日志文件不存在${NC}"
        fi
    else
        echo -e "${RED}✗ 程序未运行${NC}"
        echo -e "${YELLOW}PID文件存在但进程已停止${NC}"
        echo -e "${YELLOW}建议：删除PID文件后重新启动${NC}"
        rm -f "$PID_FILE"
    fi
    
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：停止程序
# 说明：停止正在运行的程序进程
# ========================================
stop_program() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       停止程序${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查PID文件是否存在
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}未找到PID文件，程序可能未启动${NC}"
        echo ""
        read -p "按回车键返回主菜单..."
        return 1
    fi
    
    # 读取PID
    PID=$(cat "$PID_FILE")
    
    # 检查进程是否存在
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${YELLOW}正在停止程序（PID: $PID）...${NC}"
        
        # 尝试优雅停止
        kill "$PID"
        
        # 等待进程结束
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                echo -e "${GREEN}✓ 程序已成功停止${NC}"
                rm -f "$PID_FILE"
                echo ""
                read -p "按回车键返回主菜单..."
                return 0
            fi
            sleep 1
            echo -n "."
        done
        
        # 如果优雅停止失败，强制停止
        echo ""
        echo -e "${YELLOW}优雅停止失败，尝试强制停止...${NC}"
        kill -9 "$PID"
        sleep 1
        
        if ! ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ 程序已强制停止${NC}"
            rm -f "$PID_FILE"
        else
            echo -e "${RED}错误：无法停止程序进程${NC}"
        fi
    else
        echo -e "${YELLOW}进程不存在，清理PID文件${NC}"
        rm -f "$PID_FILE"
    fi
    
    echo ""
    read -p "按回车键返回主菜单..."
}

# ========================================
# 函数：静默停止程序（内部使用）
# 说明：不显示任何信息，直接停止程序
# ========================================
stop_program_silent() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID"
            sleep 2
            if ps -p "$PID" > /dev/null 2>&1; then
                kill -9 "$PID"
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

# ========================================
# 函数：查看日志
# 说明：显示程序的运行日志
# ========================================
view_logs() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       查看日志${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${RED}日志文件不存在：$LOG_FILE${NC}"
        echo -e "${YELLOW}程序可能还未启动过${NC}"
        echo ""
        read -p "按回车键返回主菜单..."
        return 1
    fi
    
    echo -e "${YELLOW}日志文件：$LOG_FILE${NC}"
    echo -e "${YELLOW}显示最后50行日志：${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    tail -n 50 "$LOG_FILE"
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}提示：${NC}"
    echo -e "  - 使用 'tail -f $LOG_FILE' 实时查看日志"
    echo -e "  - 使用 'cat $LOG_FILE' 查看完整日志"
    echo ""
    
    read -p "按回车键返回主菜单..."
}

# ========================================
# 主程序
# 说明：程序入口，加载配置并显示菜单
# ========================================

# 加载配置文件
if [ -f "$PROGRAM_DIR/program.conf" ]; then
    source "$PROGRAM_DIR/program.conf"
else
    WORKER_NAME="$DEFAULT_WORKER_NAME"
    CPU_THREADS="$DEFAULT_CPU_THREADS"
    PROCESS_NAME="$DEFAULT_PROCESS_NAME"
fi

# 主循环
while true; do
    show_menu
    read -r CHOICE
    
    case $CHOICE in
        1)
            download_program
            ;;
        2)
            set_worker_name
            ;;
        3)
            set_cpu_threads
            ;;
        4)
            set_process_name
            ;;
        5)
            start_program
            ;;
        6)
            start_program_background
            ;;
        7)
            check_status
            ;;
        8)
            stop_program
            ;;
        9)
            view_logs
            ;;
        0)
            clear
            echo -e "${GREEN}感谢使用系统服务工具，再见！${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重新输入${NC}"
            sleep 1
            ;;
    esac
done
EOF

chmod +x wk-svc.sh

# 添加wk快捷命令到.bashrc
if ! grep -q "alias wk=" ~/.bashrc 2>/dev/null; then
    echo "alias wk='~/wk-svc.sh'" >> ~/.bashrc
    echo "已添加wk快捷命令到~/.bashrc"
fi

# 重新加载.bashrc使快捷命令立即生效
source ~/.bashrc 2>/dev/null || true

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo "现在可以使用 'wk' 命令快速打开管理面板"
echo "或者运行: ./wk-svc.sh"
echo "=========================================="
echo ""

./wk-svc.sh
