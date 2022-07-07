<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\DB;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});
Route::get('/server', function () {
    dump($_SERVER);
    die();
});
Route::get('/php', function () {
    phpinfo();
    die();
});
Route::get('/redis', function () {
    dump(Redis::connection());
    dump(session()->all());
    die();
});
Route::get('/mysql', function () {
    dump(DB::select("SHOW VARIABLES WHERE Variable_name = 'hostname';"));
    dump(DB::select("SELECT @@hostname;"));
    die();
});
