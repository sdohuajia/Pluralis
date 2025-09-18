#!/bin/bash

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "================================================================"
        echo "脚本由哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 Ctrl + C"
        echo "请选择要执行的操作:"
        echo ""
        echo "1. 安装部署节点"
        echo "2. 查看日志100行"
        echo "3. 退出"
        echo ""
        read -p "请输入选项 (1-3): " choice
        
        case $choice in
            1)
                install_and_deploy
                ;;
            2)
                view_logs
                ;;
            3)
                echo "退出脚本..."
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择"
                sleep 2
                ;;
        esac
    done
}

# 安装部署节点函数
function install_and_deploy() {
    echo "正在更新包管理器..."
    sudo apt update && sudo apt upgrade -y

    echo "正在检查并安装基础工具和依赖..."
    if ! command -v screen &> /dev/null || ! command -v curl &> /dev/null || ! command -v git &> /dev/null; then
        echo "安装基础工具和依赖..."
        sudo apt install screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
    else
        echo "基础工具已安装，跳过..."
    fi

    echo "正在检查并安装 Python 和开发工具..."
    if ! command -v python3 &> /dev/null || ! command -v pip3 &> /dev/null; then
        echo "安装 Python 和开发工具..."
        sudo apt install -y python3-pip
        sudo apt install -y build-essential libssl-dev libffi-dev python3-dev
    else
        echo "Python 工具已安装，跳过..."
    fi

    echo "正在检查并安装 Miniconda..."
    if [ ! -d "~/miniconda3" ] || ! command -v conda &> /dev/null; then
        echo "安装 Miniconda..."
        mkdir -p ~/miniconda3
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
        bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
        rm ~/miniconda3/miniconda.sh
        
        echo "正在初始化 Miniconda..."
        ~/miniconda3/bin/conda init bash
    else
        echo "Miniconda 已安装，跳过..."
    fi

    # 确保 conda 命令可用
    source ~/.bashrc

    echo "正在检查并安装 NVIDIA CUDA Toolkit..."
    if ! command -v nvcc &> /dev/null; then
        echo "安装 NVIDIA CUDA Toolkit..."
        sudo apt-get install -y nvidia-cuda-toolkit
    else
        echo "CUDA Toolkit 已安装，跳过..."
    fi

    echo "检查 NVIDIA 驱动状态..."
    nvidia-smi

    echo "检查 CUDA 编译器版本..."
    nvcc --version

    echo "正在检查并克隆 node0 仓库..."
    if [ ! -d "node0" ]; then
        echo "克隆 node0 仓库..."
        git clone https://github.com/PluralisResearch/node0
    else
        echo "node0 仓库已存在，跳过克隆..."
    fi
    
    cd node0

    echo "正在检查并创建 screen 会话..."
    if screen -list | grep -q "pluralis"; then
        echo "Screen 会话 'pluralis' 已存在，删除旧会话..."
        screen -S pluralis -X quit
        sleep 2
    fi
    echo "创建新的 screen 会话..."
    screen -S pluralis -d -m

    echo "正在检查并创建 conda 环境..."
    # 确保 conda 可用
    source ~/miniconda3/bin/activate
    
    if ! conda env list | grep -q "node0"; then
        echo "创建 conda 环境..."
        conda create -n node0 python=3.11 -y
    else
        echo "Conda 环境 'node0' 已存在，检查 Python 版本..."
        source ~/miniconda3/bin/activate node0
        python_version=$(python --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        if [ "$python_version" != "3.11" ]; then
            echo "当前 Python 版本为 $python_version，需要重新创建环境..."
            conda env remove -n node0 -y
            conda create -n node0 python=3.11 -y
        fi
    fi

    echo "正在激活 conda 环境..."
    # 确保激活正确的 conda 环境
    source ~/miniconda3/bin/activate node0
    echo "当前 Python 版本: $(python --version)"
    echo "当前 Python 路径: $(which python)"
    echo "当前 Pip 路径: $(which pip)"

    # 验证 pip 版本是否匹配 Python 3.11
    pip_version=$(pip --version | grep -o 'python3\.[0-9]\+')
    if [[ "$pip_version" != "python3.11" ]]; then
        echo "Pip 版本不匹配，尝试重新安装 pip..."
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python get-pip.py
        rm get-pip.py
        echo "Pip 重新安装完成，当前 Pip 路径: $(which pip)"
    fi

    echo "正在安装 node0 包..."
    pip install . --no-cache-dir

    echo "请输入您的 Hugging Face Token:"
    read HF_TOKEN

    echo "请输入您的邮箱地址:"
    read EMAIL_ADDRESS

    echo "正在运行 generate_script.py..."
    python generate_script.py --host_port 49200 --token $HF_TOKEN --email $EMAIL_ADDRESS

    echo ""
    echo "=========================================="
    echo "提示：不需要更改内容，输入 N 即可"
    echo "=========================================="
    echo ""

    echo "正在启动服务器..."
    # 确保在正确的 conda 环境中启动服务器
    source ~/miniconda3/bin/activate node0
    ./start_server.sh

    echo "安装完成！"
    echo "按任意键返回主菜单..."
    read -n 1
}

# 查看日志函数
function view_logs() {
    echo "=========================================="
    echo "查看服务器日志 (最新100行)"
    echo "=========================================="
    
    if [ ! -f "node0/logs/server.log" ]; then
        echo "日志文件不存在: node0/logs/server.log"
        echo "请确保服务器已经运行过"
        echo ""
        echo "按任意键返回主菜单..."
        read -n 1
        return
    fi
    
    echo "显示最新100行日志:"
    echo ""
    tail -n 100 node0/logs/server.log
    
    echo ""
    echo "按任意键返回主菜单..."
    read -n 1
}

# 启动主菜单
main_menu
