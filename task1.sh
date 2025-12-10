#!/bin/bash

# Глобальные переменные для хранения путей
LOG_FILE=""
ERROR_FILE=""
REDIRECT_OUTPUT=false
REDIRECT_ERRORS=false

# Функции для обработки действий
show_users() {
    # Получаем список пользователей и их домашние директории
    local users_info
    users_info=$(getent passwd | cut -d: -f1,6 | sort)

    if [ "$REDIRECT_OUTPUT" = true ] && [ -n "$LOG_FILE" ]; then
        echo "$users_info" >> "$LOG_FILE"
    else
        echo "$users_info"
    fi
}

show_processes() {
    # Получаем список процессов, сортируем по PID
    local processes_info
    processes_info=$(ps -e -o pid,comm --no-headers | sort -n)

    if [ "$REDIRECT_OUTPUT" = true ] && [ -n "$LOG_FILE" ]; then
        echo "$processes_info" >> "$LOG_FILE"
    else
        echo "$processes_info"
    fi
}

show_help() {
    local help_text="
Использование: $0 [ОПЦИИ]

Опции:
  -u, --users           Вывести список пользователей и их домашние директории,
                        отсортированные по алфавиту
  -p, --processes       Вывести список запущенных процессов, отсортированных по PID
  -h, --help            Показать эту справку и выйти
  -l PATH, --log PATH   Перенаправить вывод в файл по указанному пути PATH
  -e PATH, --errors PATH Перенаправить вывод ошибок (stderr) в файл по пути PATH

Примеры:
  $0 -u -l /tmp/users.log
  $0 -p -e /tmp/errors.log
  $0 -u -p -l /tmp/output.log
"

    if [ "$REDIRECT_OUTPUT" = true ] && [ -n "$LOG_FILE" ]; then
        echo "$help_text" >> "$LOG_FILE"
    else
        echo "$help_text"
    fi

    exit 0
}

# Функция проверки доступа к файлу/директории
check_path_access() {
    local path="$1"
    local type="$2"  # "file" или "dir"

    # Проверяем, существует ли родительская директория
    local parent_dir
    parent_dir=$(dirname "$path")

    if [ ! -d "$parent_dir" ]; then
        echo "Ошибка: Родительская директория '$parent_dir' не существует" >&2
        return 1
    fi

    # Проверяем права на запись
    if [ ! -w "$parent_dir" ]; then
        echo "Ошибка: Нет прав на запись в директорию '$parent_dir'" >&2
        return 1
    fi

    # Если файл уже существует, проверяем права на запись
    if [ -e "$path" ]; then
        if [ ! -w "$path" ]; then
            echo "Ошибка: Нет прав на запись в файл '$path'" >&2
            return 1
        fi
    fi

    return 0
}

# Функция для установки перенаправления вывода
setup_output_redirection() {
    if [ "$REDIRECT_OUTPUT" = true ] && [ -n "$LOG_FILE" ]; then
        if check_path_access "$LOG_FILE" "file"; then
            # Очищаем файл если существует, или создаем новый
            > "$LOG_FILE"
        else
            echo "Ошибка: Невозможно записать в файл '$LOG_FILE'" >&2
            exit 1
        fi
    fi
}

# Функция для установки перенаправления ошибок
setup_error_redirection() {
    if [ "$REDIRECT_ERRORS" = true ] && [ -n "$ERROR_FILE" ]; then
        if check_path_access "$ERROR_FILE" "file"; then
            # Перенаправляем stderr в файл
            exec 2>> "$ERROR_FILE"
        else
            echo "Ошибка: Невозможно записать в файл ошибок '$ERROR_FILE'" >&2
            exit 1
        fi
    fi
}

# Основная функция для обработки аргументов
parse_arguments() {
    local actions=()
    local show_users_flag=false
    local show_processes_flag=false

    # Используем getopts для обработки коротких опций
    while getopts ":uphl:e:-:" opt; do
        case $opt in
            u)
                show_users_flag=true
                ;;
            p)
                show_processes_flag=true
                ;;
            h)
                show_help
                ;;
            l)
                LOG_FILE="$OPTARG"
                REDIRECT_OUTPUT=true
                ;;
            e)
                ERROR_FILE="$OPTARG"
                REDIRECT_ERRORS=true
                ;;
            -)  # Обработка длинных опций
                case "${OPTARG}" in
                    users)
                        show_users_flag=true
                        ;;
                    processes)
                        show_processes_flag=true
                        ;;
                    help)
                        show_help
                        ;;
                    log)
                        # Для длинных опций с параметрами используем переменную OPTIND
                        LOG_FILE="${!OPTIND}"
                        REDIRECT_OUTPUT=true
                        OPTIND=$((OPTIND + 1))
                        ;;
                    errors)
                        ERROR_FILE="${!OPTIND}"
                        REDIRECT_ERRORS=true
                        OPTIND=$((OPTIND + 1))
                        ;;
                    log=*)
                        LOG_FILE="${OPTARG#*=}"
                        REDIRECT_OUTPUT=true
                        ;;
                    errors=*)
                        ERROR_FILE="${OPTARG#*=}"
                        REDIRECT_ERRORS=true
                        ;;
                    *)
                        echo "Неизвестная опция: --$OPTARG" >&2
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "Неизвестная опция: -$OPTARG" >&2
                exit 1
                ;;
            :)
                case $OPTARG in
                    l)
                        echo "Ошибка: опция -l требует путь к файлу" >&2
                        ;;
                    e)
                        echo "Ошибка: опция -e требует путь к файлу" >&2
                        ;;
                esac
                exit 1
                ;;
        esac
    done

    # Настраиваем перенаправление ошибок
    setup_error_redirection

    # Настраиваем перенаправление вывода
    setup_output_redirection

    # Выполняем запрошенные действия
    if [ "$show_users_flag" = true ]; then
        show_users
    fi

    if [ "$show_processes_flag" = true ]; then
        show_processes
    fi

    # Если ни одна опция не указана, показываем справку
    if [ "$show_users_flag" = false ] && [ "$show_processes_flag" = false ]; then
        show_help
    fi
}

# Главная функция
main() {
    # Проверяем, запущен ли скрипт с аргументами
    if [ $# -eq 0 ]; then
        show_help
    else
        parse_arguments "$@"
    fi
}

# Запускаем основную функцию с переданными аргументами
main "$@"